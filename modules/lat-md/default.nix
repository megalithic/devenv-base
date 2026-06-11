{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.devenv-base.lat-md;
  version = "0.11.0";
  src = pkgs.fetchurl {
    url = "https://registry.npmjs.org/lat.md/-/lat.md-${version}.tgz";
    hash = "sha256-Q342aMq1f4Fdm+xtuWdX0TtcZQX452LhmM6CzU1/ao8=";
  };
  lat-md = pkgs.buildNpmPackage {
    pname = "lat-md";
    inherit version src;
    sourceRoot = "package";
    postPatch = ''
        cp ${./package-lock.json} package-lock.json
        # Allow any OpenAI-compatible embedding provider via env (synthetic, local
        # llamacpp, openrouter, etc.). When LAT_LLM_BASE_URL is set, bypass the
        # built-in sk-/vck- prefix detection and use the env-configured endpoint.
        # OpenRouter keys also start with sk-, so reject sk-or-* before lat.md's
        # default OpenAI branch can send them to api.openai.com and fail with 401.
        substituteInPlace dist/src/search/provider.js \
          --replace 'export function detectProvider(key) {' 'export function detectProvider(key) {
      if (process.env.LAT_LLM_BASE_URL) {
          return { name: "custom", apiBase: process.env.LAT_LLM_BASE_URL, model: process.env.LAT_LLM_MODEL || "text-embedding-3-small", dimensions: Number(process.env.LAT_LLM_DIMENSIONS || 1536), headers: (k) => ({ Authorization: "Bearer " + k, "Content-Type": "application/json" }) };
      }
      if (key.startsWith("sk-or-")) {
          throw new Error("OpenRouter keys are not OpenAI keys. Set LAT_LLM_BASE_URL, LAT_LLM_MODEL, and LAT_LLM_DIMENSIONS for an OpenAI-compatible embeddings endpoint, or set LAT_LLM_KEY to an OpenAI/Vercel embeddings key.");
      }'
    '';
    npmDepsHash = "sha256-1n3XaT63b+rFl2KsS4mUz/Y4ko6+bit+a3etHk1r0C4=";
    dontBuild = true;
  };

  skillFile = pkgs.writeText "lat-md-SKILL.md" (builtins.readFile ./SKILL.md);
  extensionFile = pkgs.writeText "lat.ts" (builtins.readFile ./lat.ts);
in
{
  options.devenv-base.lat-md.enable = lib.mkEnableOption "devenv-base lat.md tooling" // {
    default = true;
  };

  config = {
    packages = lib.optional cfg.enable lat-md;

    # Always run enter-shell.sh — installs symlinks when enabled, removes
    # leftover symlinks when disabled so pi does not load a stale extension
    # that calls a `lat` binary no longer on PATH.
    enterShell =
      if cfg.enable then
        "bash ${./enter-shell.sh} enable ${skillFile} ${extensionFile}"
      else
        "bash ${./enter-shell.sh} disable";
  };
}
