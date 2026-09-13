# 06 — Same-machine prefill + layered previous performance

**What to build:** Real history queries replace the sample data. When an exercise starts on a machine, set rows prefill from that machine's most recent same-index sets — one tap confirms a repeat set. The previous-performance sheet shows the three real layers: this machine, same equipment model at other gyms, and the exercise on any equipment — each labeled, with fallback layers shown as reference and never prefilled.

**Blocked by:** 04, 05.

**Status:** ready-for-agent

- [ ] Prefill draws only from the same MachineInstance's history; a machine with no history prefills nothing
- [ ] The "previous" column shows same-index sets from the last workout containing this exercise on this machine
- [ ] Layer 2 finds machines sharing the same EquipmentModel at other gyms (the travel case)
- [ ] Layer 3 aggregates the exercise across all equipment, labeled not-comparable
- [ ] Layer selection logic lives in Domain/ free of UI imports, unit-tested
