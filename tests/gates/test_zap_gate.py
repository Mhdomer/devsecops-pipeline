import json

import pytest

from zap_gate import evaluate, load_fail_rules

CONF = """# comment line
10021\tFAIL\t(X-Content-Type-Options Header Missing)
10049\tWARN\t(Storable and Cacheable Content)
10038\tFAIL\t(Content Security Policy (CSP) Header Not Set)
"""


def report(*alerts):
    return {"site": [{"@name": "http://app:5000", "alerts": [
        {"pluginid": pid, "riskcode": risk, "name": name, "count": "1"}
        for pid, risk, name in alerts
    ]}]}


@pytest.fixture
def fail_rules(tmp_path):
    conf = tmp_path / "zap.conf"
    conf.write_text(CONF)
    return load_fail_rules(conf)


def test_load_fail_rules_reads_only_fail_entries(fail_rules):
    assert fail_rules == {"10021", "10038"}


def test_clean_report_passes(fail_rules):
    assert evaluate(report(), fail_rules) == []


def test_low_and_medium_alerts_outside_fail_list_pass(fail_rules):
    r = report(("10049", "0", "Storable and Cacheable Content"),
               ("10098", "2", "Cross-Domain Misconfiguration"))
    assert evaluate(r, fail_rules) == []


def test_alert_on_fail_list_blocks_even_when_low_risk(fail_rules):
    blocking = evaluate(report(("10021", "1", "X-Content-Type-Options Header Missing")), fail_rules)
    assert [b["pluginid"] for b in blocking] == ["10021"]


def test_high_risk_alert_blocks_even_when_not_on_fail_list(fail_rules):
    blocking = evaluate(report(("10097", "3", "Hash Disclosure")), fail_rules)
    assert [b["pluginid"] for b in blocking] == ["10097"]


def test_main_exit_codes(tmp_path, fail_rules):
    from zap_gate import main

    conf = tmp_path / "zap.conf"
    conf.write_text(CONF)
    clean = tmp_path / "clean.json"
    clean.write_text(json.dumps(report()))
    dirty = tmp_path / "dirty.json"
    dirty.write_text(json.dumps(report(("10097", "3", "Hash Disclosure"))))

    assert main([str(clean), str(conf)]) == 0
    assert main([str(dirty), str(conf)]) == 1
    assert main([str(tmp_path / "missing.json"), str(conf)]) == 2


def test_main_wrong_arguments_is_an_error():
    from zap_gate import main

    assert main([]) == 2
