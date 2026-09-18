# Workout tracking

A workout groups the user's training session, including lifting and cardio, into one saved record.

## Language

**Workout**: The complete training session, from its start to Finish, saved as one History entry.
It may contain lifting, cardio, or both.

**Cardio segment**: One recorded occurrence of a cardio activity within a workout, with its own
active time, measurements and optional route. Pausing and resuming continues the same segment.
_Avoid_: Cardio set, separate workout (when referring to a segment).

**Active time**: Time spent recording a cardio segment, excluding pauses.
_Avoid_: Elapsed time when pauses are excluded.

**Measured distance**: Distance supplied by a sensor or location source, with its source retained.
It may be an estimate and is distinct from distance entered from a machine display.

**Entered distance**: A distance the user explicitly types, preserving their value and unit.
It may override the displayed measured distance without erasing the measurement's provenance.
