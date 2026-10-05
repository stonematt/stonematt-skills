# The `stone-` namespace is a convention, not a rule

ADR-0002 put the `stone-` prefix on every shipped skill, for uniformity, so a generic name could never collide in the flat Central store. In practice the collision risk sits with common verbs (`commit`, `merge`, `journal`), not with distinctive names like `obsidian-quick-capture`, and a prefix on those only costs a longer `/name`. We now prefix a skill when its bare name is a common verb or otherwise likely to exist in another pack, and let distinctive names ship bare. The validation gate no longer enforces the prefix; it is a judgment made when a skill is named or promoted.

Trade-off accepted: a bare name can still collide with a future skill from another pack. The second install clobbers the first, so a collision shows up as a rename, not as data loss.
