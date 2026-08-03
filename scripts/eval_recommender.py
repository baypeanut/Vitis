#!/usr/bin/env python3
"""
eval_recommender.py
===================
Reference implementation of the metrics used to judge Pari's recommender, plus a
self-test that proves the maths is right before anyone trusts a number it produces.

Why this exists
---------------
The recommender currently ships unevaluated. Its quality is an assumption. Nothing
about ranking should change again until a holdout can say whether the change helped,
and a metric nobody has checked is worse than no metric, because it gets quoted.

What is measured
----------------
NDCG@k        Did the wines this person actually liked end up near the top.
Coverage      What share of the catalog ever gets recommended to anyone.
Gini          How unequally exposure is spread. The Parkerization guardrail.

Coverage and Gini are not secondary. A recommender that scores well on NDCG by
showing everyone the same forty bottles has not solved the problem, it has moved it.

Usage
-----
    python3 eval_recommender.py --self-test     verify the metric implementations
    python3 eval_recommender.py --demo          run against a simulated population

The SQL twin of this file lives in supabase/eval/recommender_eval.sql and runs
where the real data is.
"""

from __future__ import annotations

import argparse
import math
import random
from collections import Counter

# A wine rated at or below this contributes nothing. Above it, relevance is graded,
# so a 10 counts for more than a 7 rather than both being "a hit".
NEUTRAL_RATING = 6.0


def relevance(rating: float) -> float:
    """Graded relevance in 0..4 from a 1-10 rating."""
    return max(0.0, rating - NEUTRAL_RATING)


def dcg(gains: list[float]) -> float:
    return sum(g / math.log2(i + 2) for i, g in enumerate(gains))


def ndcg_at_k(ranked_wine_ids: list, held_out: dict, k: int = 20) -> float | None:
    """Normalised discounted cumulative gain over a user's held-out tastings.

    `held_out` maps wine_id -> rating. Returns None when the user has no positive
    held-out wine, because NDCG is undefined there and averaging in a zero would
    quietly punish rankers for users who simply liked nothing.
    """
    gains = [relevance(held_out.get(w, 0.0)) for w in ranked_wine_ids[:k]]
    ideal = sorted((relevance(r) for r in held_out.values()), reverse=True)[:k]
    ideal_dcg = dcg(ideal)
    if ideal_dcg == 0:
        return None
    return dcg(gains) / ideal_dcg


def coverage(recommendation_lists: list[list], catalog_size: int) -> float:
    """Share of the catalog that appears in at least one recommendation list."""
    if catalog_size <= 0:
        return 0.0
    seen = {w for lst in recommendation_lists for w in lst}
    return len(seen) / catalog_size


def gini(counts: list[int]) -> float:
    """Inequality of exposure. 0 = every wine shown equally, 1 = one wine takes all."""
    values = sorted(c for c in counts if c > 0)
    n = len(values)
    total = sum(values)
    if n <= 1 or total == 0:
        return 0.0
    weighted = sum((i + 1) * v for i, v in enumerate(values))
    return (2.0 * weighted) / (n * total) - (n + 1.0) / n


def top_share(counts: list[int], fraction: float = 0.01) -> float:
    """Share of all impressions taken by the most-exposed `fraction` of wines."""
    values = sorted((c for c in counts if c > 0), reverse=True)
    total = sum(values)
    if not values or total == 0:
        return 0.0
    cut = max(1, math.ceil(len(values) * fraction))
    return sum(values[:cut]) / total


# ─────────────────────────── self-test ───────────────────────────


def _self_test() -> int:
    failures: list[str] = []

    def check(name: str, condition: bool, detail: str = "") -> None:
        if condition:
            print(f"  pass  {name}")
        else:
            print(f"  FAIL  {name} {detail}")
            failures.append(name)

    print("NDCG")
    held = {"a": 10.0, "b": 9.0, "c": 8.0, "d": 2.0, "e": 2.0}
    perfect = ["a", "b", "c", "d", "e"]
    reversed_ = list(reversed(perfect))
    check("perfect ranking scores 1.0", abs(ndcg_at_k(perfect, held) - 1.0) < 1e-9)
    check("reversed ranking scores below perfect", ndcg_at_k(reversed_, held) < 0.9,
          f"got {ndcg_at_k(reversed_, held):.3f}")
    check("empty ranking scores 0", ndcg_at_k([], held) == 0.0)
    check("no positive held-out returns None", ndcg_at_k(perfect, {"d": 2.0}) is None)
    check("ranking only irrelevant items scores 0",
          ndcg_at_k(["d", "e"], held) == 0.0)
    check("truncation at k is respected",
          ndcg_at_k(["d", "e", "a"], held, k=2) == 0.0)

    print("Gini")
    check("uniform exposure is 0", abs(gini([5, 5, 5, 5])) < 1e-9)
    many = [1] * 99 + [10_000]
    check("one dominant wine scores high", gini(many) > 0.9, f"got {gini(many):.3f}")
    check("empty is 0", gini([]) == 0.0)
    # Wines with zero impressions are dropped, so Gini measures inequality only
    # among wines that were shown at least once. That is a real limitation, not an
    # oversight: the never-recommended tail is what `coverage` is for, and the SQL
    # twin cannot see those wines either since the log has no row for them.
    check("zero-impression wines are excluded, not counted as equal",
          gini([0, 0, 0, 5, 5]) == gini([5, 5]))
    check("gini stays in range", all(0.0 <= gini(c) <= 1.0
                                    for c in ([1, 2, 3], [7], [1] * 50 + [900])))

    print("Top share")
    check("uniform 1% share is small", top_share([1] * 1000) < 0.02)
    check("dominant wine takes most", top_share([1] * 99 + [10_000]) > 0.9)

    print("Coverage")
    check("full coverage is 1.0", abs(coverage([[1, 2], [3, 4]], 4) - 1.0) < 1e-9)
    check("half coverage is 0.5", abs(coverage([[1, 2]], 4) - 0.5) < 1e-9)
    check("empty catalog is 0", coverage([[1]], 0) == 0.0)

    print()
    if failures:
        print(f"{len(failures)} FAILED: {', '.join(failures)}")
        return 1
    print("all metric checks passed")
    return 0


# ─────────────────────────── demo ───────────────────────────


def _demo(seed: int = 7) -> int:
    """Simulate a population and show that the metrics separate good rankers from bad.

    Each user has a latent palate. A wine's appeal is how well it matches. A ranker
    that knows the palate should beat one that ranks by popularity, which should beat
    random. If the metrics cannot show that ordering, they are not measuring anything.
    """
    rng = random.Random(seed)
    n_wines, n_users, k = 500, 200, 20

    wines = {w: rng.uniform(0, 1) for w in range(n_wines)}
    popularity = {w: rng.paretovariate(1.2) for w in range(n_wines)}

    def rating(user_palate: float, wine: int) -> float:
        distance = abs(user_palate - wines[wine])
        return max(1.0, min(10.0, 10.0 - distance * 12 + rng.gauss(0, 0.8)))

    rankers = {
        "oracle (knows the palate)": lambda p, pool: sorted(pool, key=lambda w: abs(p - wines[w])),
        "popularity only": lambda p, pool: sorted(pool, key=lambda w: -popularity[w]),
        "random": lambda p, pool: rng.sample(pool, len(pool)),
    }

    results = {}
    for name, rank in rankers.items():
        scores, lists, impressions = [], [], Counter()
        for _ in range(n_users):
            palate = rng.uniform(0, 1)
            pool = rng.sample(range(n_wines), 120)
            held = {w: rating(palate, w) for w in rng.sample(pool, 40)}
            ranked = rank(palate, pool)
            s = ndcg_at_k(ranked, held, k)
            if s is not None:
                scores.append(s)
            lists.append(ranked[:k])
            impressions.update(ranked[:k])
        results[name] = {
            "ndcg": sum(scores) / len(scores) if scores else 0.0,
            "coverage": coverage(lists, n_wines),
            "gini": gini(list(impressions.values())),
            "top1pct": top_share(list(impressions.values())),
        }

    print(f"{'ranker':<28}{'NDCG@20':>9}{'coverage':>10}{'gini':>8}{'top1%':>8}")
    print("-" * 63)
    for name, r in results.items():
        print(f"{name:<28}{r['ndcg']:>9.3f}{r['coverage']:>10.2f}{r['gini']:>8.3f}{r['top1pct']:>8.2f}")

    print()
    ok = results["oracle (knows the palate)"]["ndcg"] > results["random"]["ndcg"]
    concentrating = results["popularity only"]["gini"] > results["random"]["gini"]
    print("oracle beats random on NDCG:", "yes" if ok else "NO - metric is broken")
    print("popularity ranker concentrates exposure:", "yes" if concentrating else "no")
    print()
    print("Read: coverage is the sharpest signal here. The popularity ranker reaches")
    print("roughly a fifth of the catalog while the others reach all of it, and gini")
    print("moves in the same direction but less dramatically. A ranker can look fine")
    print("on accuracy while quietly serving a small slice of the catalog, which is")
    print("why none of these three numbers is reported on its own.")
    return 0 if ok else 1


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--self-test", action="store_true", help="verify the metric implementations")
    ap.add_argument("--demo", action="store_true", help="run against a simulated population")
    args = ap.parse_args()
    if args.self_test:
        return _self_test()
    if args.demo:
        return _demo()
    ap.print_help()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
