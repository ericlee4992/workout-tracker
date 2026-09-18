# One app workout, separate activity-specific sensor sessions

Store cardio as segments of the existing Workout, separate from weight×reps sets, because the
user wants one History entry without inventing strength volume or records for cardio. A mixed
workout uses consecutive activity-specific HealthKit sessions: Apple's arbitrary mixed-activity
contract does not support treating strength and running as interchangeable activities inside
one HealthKit workout. Preserve whole-session HR history and sum only disjoint energy spans;
otherwise changing the focused activity could erase earlier readings or double-count calories.
