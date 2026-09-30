# Recomendarr in one page

**Recomendarr reads your Letterboxd diary and recommends unseen films in
two lanes, each with an explanation.** [Full paper →](./how-we-recommend-films.md)

![The two lanes](./assets/screenshots/lanes.png)

## How it works

1. **Profile:** weighted diary themes, genres and people, capped per film.
2. **Candidates:** Letterboxd browse and Similar pages, plus 300 collaborative
   candidates, followed by metadata enrichment and watched-film filters.
3. **EASE:** a linear co-liking model fitted on **2,000 public training
   profiles**, with **15,000 films and λ = 2000**. Each film stores 300 weights.
4. **For you:** half EASE rank, half community-rating rank, with liked-film
   explanations. **Your taste:** content match, EASE and a personal quality
   curve/floor learned from your ratings.

## Updated evidence · September 30, 2026

The headlines use **100 new independent users**, 200 temporal test windows
and 3,945 later first watches rated ≥ 3.5★ or liked when
unrated. The older 183 users are development data, including λ tuning;
100 of them now overlap production training.

| Method | Later favourites found |
| --- | ---: |
| Content engine, top 100 | 10.1 % |
| Same pool sorted by rating, top 100 | 5.2 % |
| Most watched, top 100 | 17.5 % |
| EASE liked, top 100 | 29.1 % |
| For you, top 100 | 20.4 % |
| Both lanes, up to 200 films | 27.4 % |

**Did the larger model help?** On these same users, the original
400-training-user model (500 collected, λ = 1000) had EASE recall
26.8 %; the
current model reaches 29.1 %. The paired
change is **+2.3 [+1.3, +3.2] pp**. For the actual "For you" lane,
the change is **+0.9 [+0.3, +1.6] pp**. These 95 % intervals
resample whole users. Both recall intervals exclude zero: the gain is
supported, but modest.
Account count, sampling mix, λ and film coverage changed together.

A separate taste diagnostic ranks films the users watched: community rating
AUC 0.758, stored EASE 0.686,
engine 0.577. Rare-film coverage remains low: the engine finds
29 of 1415
rare later favourites, EASE 18.
The personal floor/curve has 4.6 %
observed bad picks, versus 7.0 % without
a floor, among recommendations later watched.

## What makes the comparison reviewable

- Production code, fixed settings and startup commit recorded in public data.
- Identical users/windows for both snapshots; final runs fully offline.
- Zero test/training overlap; original 2,000-user training data unchanged.
- Aggregate sample evidence; case profiles published under pseudonyms.
- Tests remain retrospective and selected by diary eligibility. They do not
  measure discovery value; the two-lane union also uses twice the list budget.
