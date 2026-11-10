"""Runs the shell steps of .github/workflows/service-ci.yml for real (docker stubbed, config-repo local).
   Usage: python3 tests/ci/test_service_ci_steps.py"""
import os, subprocess, tempfile, yaml
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
WF = yaml.safe_load(open(ROOT / ".github/workflows/service-ci.yml"))
def step(job, name):
    return next(s for s in WF["jobs"][job]["steps"] if s.get("name", "").startswith(name))["run"]

def run(script, env, cwd, pre=""):
    f = Path(cwd) / "step.sh"; f.write_text(pre + "\n" + script)
    e = {**os.environ, **env}
    return subprocess.run(["bash", "--noprofile", "--norc", "-eo", "pipefail", str(f)], cwd=cwd, env=e, capture_output=True, text=True)

def git(d, *a): return subprocess.run(["git", "-C", str(d), *a], capture_output=True, text=True, check=True).stdout.strip()

ok = True
def check(name, cond, extra=""):
    global ok; ok &= bool(cond); print(("ok   " if cond else "FAIL ") + name, extra if not cond else "")

with tempfile.TemporaryDirectory() as tmp:
    # 1. image reference + service-name validation
    meta = step("build", "Validate the service name")
    for svc, image_name, valid in [("shop-cart", "", True), ("Shop", "", False), ("shop_cart", "", False), ("a" * 41, "", False), ("1shop", "", False), ("shop-cart", "cart-api", True)]:
        out = Path(tmp) / "out"; out.write_text("")
        r = run(meta, {"SERVICE": svc, "IMAGE_NAME": image_name, "GITHUB_REPOSITORY_OWNER": "QuanTran2510", "GITHUB_SHA": "abcdef0123456789", "GITHUB_OUTPUT": str(out)}, tmp)
        check(f"name {svc[:12]!r} image_name={image_name!r} -> {'accepted' if valid else 'rejected'}", (r.returncode == 0) == valid, r.stderr)
        if valid:
            want = f"image=ghcr.io/quantran2510/{image_name or svc}\ntag=abcdef0"
            check("  output is lower-case owner + 7-char sha", out.read_text().strip() == want, out.read_text())

    # 2. the non-root guardrail, with docker stubbed
    guard = step("build", "Guardrail")
    for user, passes in [("10001", True), ("appuser", True), ("10001:10001", True), ("", False), ("0", False), ("root", False), ("0:0", False), ("root:root", False)]:
        stub = f"docker() {{ echo '{user}'; }}\nexport -f docker"
        r = run(guard, {"IMAGE": "ghcr.io/o/x", "TAG": "abc"}, tmp, pre=stub)
        check(f"image user {user!r:14} -> {'passes' if passes else 'fails the build'}", (r.returncode == 0) == passes, r.stdout + r.stderr)

    # 3. deploy step against a local config-repo
    remote, seed, work = Path(tmp) / "remote.git", Path(tmp) / "seed", Path(tmp) / "run"
    subprocess.run(["git", "init", "-q", "--bare", "-b", "main", str(remote)], check=True)
    subprocess.run(["git", "init", "-q", "-b", "main", str(seed)], check=True)
    for k, v in (("user.email", "t@t"), ("user.name", "t")): git(seed, "config", k, v)
    (seed / "apps/shop-cart").mkdir(parents=True)
    (seed / "apps/shop-cart/values.yaml").write_text('# Created by the portal\nimage:\n  repository: docker.io/nginxinc/nginx-unprivileged\n  tag: "1.27-alpine"\ncontainerPort: 8080\nprobes:\n  path: /healthz\n')
    git(seed, "add", "-A"); git(seed, "commit", "-m", "portal: shop-cart"); git(seed, "remote", "add", "origin", str(remote)); git(seed, "push", "-q", "-u", "origin", "main")
    work.mkdir(); subprocess.run(["git", "clone", "-q", str(remote), str(work / "config-repo")], check=True)
    for k, v in (("user.email", "t@t"), ("user.name", "t")): git(work / "config-repo", "config", k, v)
    deploy = step("deploy", "Point the service")
    summary = work / "summary.md"; summary.write_text("")
    env = {"SERVICE": "shop-cart", "IMAGE": "ghcr.io/quantran2510/shop-cart", "TAG": "9f8e7d6", "GITHUB_REPOSITORY": "QuanTran2510/shop-cart", "GITHUB_SHA": "9f8e7d6aaaaaaaa", "GITHUB_STEP_SUMMARY": str(summary)}
    r = run(deploy, env, work)
    check("deploy: exits 0", r.returncode == 0, r.stdout + r.stderr)
    values = git(remote, "show", "main:apps/shop-cart/values.yaml")
    check("deploy: repository and tag rewritten, other keys untouched",
          "repository: ghcr.io/quantran2510/shop-cart\n" in values and 'tag: "9f8e7d6"' in values and "containerPort: 8080" in values and "path: /healthz" in values, values)
    check("deploy: commit message names service, tag and source", git(remote, "log", "-1", "--format=%s", "main") == "ci(shop-cart): 9f8e7d6 (QuanTran2510/shop-cart@9f8e7d6)", git(remote, "log", "-1", "--format=%s", "main"))
    n1 = git(remote, "rev-list", "--count", "main")
    r = run(deploy, env, work)
    check("deploy: same tag again -> no new commit", r.returncode == 0 and git(remote, "rev-list", "--count", "main") == n1 and "nothing to do" in r.stdout, r.stdout)
    r = run(deploy, {**env, "TAG": "1111111", "GITHUB_SHA": "1111111bbbbbbbb"}, work)
    check("deploy: new tag -> one new commit", r.returncode == 0 and int(git(remote, "rev-list", "--count", "main")) == int(n1) + 1, r.stdout + r.stderr)
    # a concurrent change in the config-repo (e.g. the optimiser's PR merged) must not break the push
    other = Path(tmp) / "other"; subprocess.run(["git", "clone", "-q", str(remote), str(other)], check=True)
    for k, v in (("user.email", "t@t"), ("user.name", "t")): git(other, "config", k, v)
    (other / "envs").mkdir(); (other / "envs/x.yaml").write_text("a: 1\n"); git(other, "add", "-A"); git(other, "commit", "-m", "concurrent"); git(other, "push", "-q")
    r = run(deploy, {**env, "TAG": "2222222", "GITHUB_SHA": "2222222cccccccc"}, work)
    check("deploy: rebases over a concurrent commit and pushes", r.returncode == 0 and 'tag: "2222222"' in git(remote, "show", "main:apps/shop-cart/values.yaml") and "concurrent" in git(remote, "log", "--format=%s", "main"), r.stdout + r.stderr)
    # service not registered yet -> warning + instructions, no failure
    summary.write_text("")
    r = run(deploy, {**env, "SERVICE": "not-registered"}, work)
    check("deploy: unregistered service -> exit 0 with portal instructions", r.returncode == 0 and "not registered" in summary.read_text() and "ghcr.io/quantran2510/shop-cart" in summary.read_text() and "::warning::" in r.stdout, summary.read_text())
print("ALL STEP CHECKS PASSED" if ok else "SOME CHECKS FAILED")
raise SystemExit(0 if ok else 1)
