# ─── devenv-base: elixir module ─────────────────────────────────────────────
# Parent module for the Elixir/BEAM ecosystem. Provides shared parse helpers
# (toolVersions, appName, configInt) consumed by sub-modules, sets up the
# BEAM toolchain from .tool-versions, mixes in rebar3/Node, the expert LSP,
# treefmt mix-format, and opts into sub-modules.
#
# Sub-modules (each separately enable'd):
#   devenv-base.elixir.phoenix   — Endpoint port, processes.phoenix, start-phx, status, tidewave MCP, app:* tasks
#   devenv-base.elixir.postgres  — Repo port, services.postgres, PG_*_TABLE envs, status pg block
#   devenv-base.elixir.worktree  — SNAME detection, disableListeners, pre-/post- hooks, worktree:* tasks
{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.devenv-base.elixir;

  # ── .tool-versions parser ────────────────────────────────────────────────
  # Reads .tool-versions at nix eval time. Major-version pinning only
  # (nixpkgs ships major channels: erlang_28, elixir_1_19, nodejs_24).
  toolVersions =
    let
      lines = lib.splitString "\n" (builtins.readFile ./.tool-versions);
      valid = lib.filter (l: l != "" && !(lib.hasPrefix "#" l)) lines;
      parse =
        line:
        let
          parts = lib.splitString " " line;
        in
        lib.nameValuePair (builtins.head parts) (builtins.elemAt parts 1);
    in
    lib.listToAttrs (map parse valid);

  # ── App name parsed from mix.exs ─────────────────────────────────────────
  appName =
    let
      content = builtins.readFile ./mix.exs;
      lines = lib.splitString "\n" content;
      appLines = lib.filter (l: builtins.match ".*app: :([a-z_]+).*" l != null) lines;
    in
    if appLines == [ ] then
      "app"
    else
      builtins.head (builtins.match ".*app: :([a-z_]+).*" (builtins.head appLines));

  # ── Generic config/dev.exs integer parser ────────────────────────────────
  # Scans for a `config :<app>, <moduleGlob>` block and extracts the first
  # integer value for the given `attr:`. Uses builtins.readFile so nix
  # re-evaluates when the file changes.
  #
  #   configInt ".*Repo" "port" 5432     → scans Repo blocks for port:
  #   configInt ".*Endpoint" "port" 4000 → scans Endpoint blocks for port:
  #
  configInt =
    moduleGlob: attr: default:
    let
      devConfig = if builtins.pathExists ./config/dev.exs then builtins.readFile ./config/dev.exs else "";
      lines = lib.splitString "\n" devConfig;
      blockPattern = "config :${appName}, ${moduleGlob},.*";
      attrPattern = ".*${attr}:[^0-9]*([0-9]+).*";
      result =
        lib.foldl'
          (
            acc: line:
            let
              isBlockStart = builtins.match blockPattern line != null;
              isNewConfig = !isBlockStart && builtins.match "config :.*" line != null;
              valMatch = builtins.match attrPattern line;
            in
            if isBlockStart then
              acc // { inBlock = true; }
            else if acc.inBlock && isNewConfig then
              acc // { inBlock = false; }
            else if acc.inBlock && valMatch != null && acc.val == null then
              acc // { val = lib.strings.toInt (builtins.head valMatch); }
            else
              acc
          )
          {
            inBlock = false;
            val = null;
          }
          lines;
    in
    if result.val != null then result.val else default;

  # ── Version helpers ───────────────────────────────────────────────────────
  major = v: builtins.head (lib.splitString "." v);
  minorMajor =
    v:
    let
      clean = builtins.head (lib.splitString "-" v);
      parts = lib.splitString "." clean;
    in
    "${builtins.elemAt parts 0}_${builtins.elemAt parts 1}";

  erlangAttr = "erlang_${major toolVersions.erlang}";
  elixirAttr = "elixir_${minorMajor toolVersions.elixir}";
  beamPkgs = pkgs.beam.packages.${erlangAttr};
  erlangPkg = beamPkgs.erlang;
  elixirPkg = beamPkgs.${elixirAttr};
  nodePkg = pkgs.nodejs_24;

  # ── Default expert LSP package ────────────────────────────────────────────
  defaultExpertPkg =
    let
      version = "0.1.5";
      asset = "expert_darwin_arm64";
      hash = "sha256-5f2M5coqn3ZV0io536LSliYKpRxaj6/UOpg9OlftM58=";
    in
    pkgs.stdenv.mkDerivation {
      pname = "expert";
      inherit version;
      src = pkgs.fetchurl {
        url = "https://github.com/expert-lsp/expert/releases/download/v${version}/${asset}";
        inherit hash;
      };
      dontUnpack = true;
      installPhase = ''
        mkdir -p $out/bin
        install -m755 $src $out/bin/expert
      '';
      meta.mainProgram = "expert";
    };

  expertPkg = cfg.lsp.expert.package;

in
{
  imports = [
    ./phoenix
    ./postgres
    ./worktree
  ];

  options.devenv-base.elixir = {
    enable = lib.mkEnableOption "devenv-base Elixir/BEAM module" // {
      default = false;
    };

    # ── Shared internals exposed for sub-modules ────────────────────────────
    # (read-only; computed from the project, not user-configured)
    _appName = lib.mkOption {
      type = lib.types.str;
      default = appName;
      internal = true;
      description = "App name parsed from mix.exs (e.g. 'rx').";
    };
    _configInt = lib.mkOption {
      type = lib.types.raw;
      default = configInt;
      internal = true;
      description = "config/dev.exs integer parser function.";
    };
    _elixirPkg = lib.mkOption {
      type = lib.types.package;
      default = elixirPkg;
      internal = true;
    };
    _toolVersions = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = toolVersions;
      internal = true;
    };
    _erlangAttr = lib.mkOption {
      type = lib.types.str;
      default = erlangAttr;
      internal = true;
    };
    _elixirAttr = lib.mkOption {
      type = lib.types.str;
      default = elixirAttr;
      internal = true;
    };

    # ── LSP options ─────────────────────────────────────────────────────────
    lsp.enable = lib.mkEnableOption "Elixir LSP tooling" // {
      default = true;
    };
    lsp.expert = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = cfg.lsp.enable;
        description = "Install the expert LSP binary. Set to false to use lexical/elixir-ls instead.";
      };
      package = lib.mkOption {
        type = lib.types.package;
        default = defaultExpertPkg;
        description = "The expert LSP package. Override to supply a custom build.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # ── rebar3 OTP 29 overlay ─────────────────────────────────────────────
    # rebar3 3.27.0 fails to build under OTP 29: its test sources trip the new
    # "exported variable from list subexpression" warning. Drop the test dirs.
    overlays = [
      (_final: prev: {
        rebar3 = prev.rebar3.overrideAttrs (old: {
          postPatch = (old.postPatch or "") + ''
            rm -rf apps/rebar/test
          '';
        });
      })
    ];

    # ── Languages ─────────────────────────────────────────────────────────
    languages = {
      erlang = {
        enable = true;
        package = erlangPkg;
      };
      elixir = {
        enable = true;
        package = elixirPkg;
      };
      javascript = {
        enable = true;
        package = nodePkg;
        npm.enable = true;
      };
    };

    # ── Packages ──────────────────────────────────────────────────────────
    packages =
      lib.optionals cfg.lsp.expert.enable [ expertPkg ] ++ pkgs.lib.optionals pkgs.stdenv.isLinux [ ];

    # ── mix-format via treefmt ─────────────────────────────────────────────
    devenv-base.treefmt = {
      programs.mix-format = {
        enable = true;
        package = elixirPkg;
      };
      settings.formatter.mix-format.includes = [ "\\.(ex|exs|heex)$" ];
      settings.formatter.prettier.excludes = [ "assets/**" ];
    };

    dotenv.enable = true;
  };
}
