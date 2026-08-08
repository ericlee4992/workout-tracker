# 03 — Real gym & machine creation

**What to build:** The "Add Gym…" and "Add Machine…" buttons (currently no-ops in the prototype) create and persist real records. Creating a machine means: label it, optionally pick a model from the catalog (searchable), optionally set a default unit. Gyms get a name, optional city, and default unit. Both survive relaunch and appear everywhere gyms/machines are listed or picked.

**Blocked by:** 01, 02.

**Status:** ready-for-agent

- [ ] Add Gym flow creates a persisted Gym with name and default unit; appears in Gyms tab and gym picker
- [ ] Add Machine flow creates a persisted MachineInstance linked to the gym, optionally to a catalog model
- [ ] Machine picker in active workout lists real machines for the current gym
- [ ] Users can add a missing equipment model inline (user ID space) when the catalog lacks it
