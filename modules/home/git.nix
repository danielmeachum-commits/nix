{ config, pkgs, lib, ... }:

{
  options.custom.git.enable = lib.mkEnableOption "git tooling";

  config = lib.mkIf config.custom.git.enable {
    programs.git = {
      enable = true;

      settings = {
        user.name  = "Hobbes";
        user.email = "daniel.meachum@gmail.com";

        init.defaultBranch = "main";
        pull.rebase = true;
        rebase.autoStash = true;
        rerere.enabled = true;
        push.autoSetupRemote = true;
        column.ui = "auto";
        branch.sort = "-committerdate";
        diff.algorithm = "histogram";
        merge.conflictstyle = "zdiff3";
        fetch.prune = true;
        help.autocorrect = 10;
        credential.helper = "${pkgs.gh}/bin/gh auth git-credential";

        # Use 1Password's SSH agent for git over SSH (and signing, if enabled).
        # Once you've set up "Use SSH agent" in 1Password, you can also flip
        # commit signing on:
        #
        #   commit.gpgsign = true;
        #   gpg.format = "ssh";
        #   gpg.ssh.program = "/etc/profiles/per-user/hobbes/bin/op-ssh-sign";
        #   user.signingkey = "ssh-ed25519 AAAA...your-pub-key";

        alias = {
          st = "status -sb";
          co = "checkout";
          sw = "switch";
          br = "branch";
          lg = "log --graph --pretty=format:'%C(yellow)%h%Creset%C(auto)%d%Creset %s %C(blue)<%an>%Creset %C(green)(%cr)%Creset' --abbrev-commit --all";
          undo = "reset --soft HEAD~1";
          amend = "commit --amend --no-edit";
        };
      };

      ignores = [
        ".direnv/"
        ".envrc.local"
        "*.swp"
        ".DS_Store"
        "node_modules/"
        "__pycache__/"
        ".venv/"
        ".idea/"
        ".vscode/"
      ];
    };

    programs.delta = {
      enable = true;
      enableGitIntegration = true;
      options = {
        navigate = true;
        line-numbers = true;
        side-by-side = true;
        syntax-theme = "ansi";
      };
    };

    programs.lazygit.enable = true;
  };
}
