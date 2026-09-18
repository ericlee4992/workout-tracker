# Append-only live sensor checkpoints

An unfinished workout checkpoints heartbeats as individual rows and energy/zone metadata as
small scalars. Rewriting a growing heartbeat blob on each tick made writes grow quadratically;
rows preserve relaunch fidelity without repeatedly encoding/writing the earlier series. Any
finish path, including stray recovery without a live coordinator, folds those rows into the
frozen summary and removes the transient checkpoint. Schema 10 has not been installed or
exported by a real build; earlier v10 checkpoint shapes were development-only.
