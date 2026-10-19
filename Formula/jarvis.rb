class Jarvis < Formula
  desc "Always-on memory and voice commands for the Mac"
  homepage "https://github.com/yashMangal19/jarvis"
  url "https://github.com/yashMangal19/jarvis/archive/refs/tags/v0.1.0.tar.gz"
  # PLACEHOLDER: no v0.1.0 tag exists yet. Replace with the tarball's sha256 once the tag is pushed.
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"
  license "MIT"
  head "https://github.com/yashMangal19/jarvis.git", branch: "main"

  # Builds from source with `swift build`, which needs Swift 6.0+ (Xcode 16 or Command Line Tools 16),
  # and those need macOS 14.5 or later. Sonoma is the closest floor Homebrew can express; on 14.0-14.4
  # install/install.sh checks the Swift version and stops with an explanation. Jarvis itself runs on 13+.
  # No `depends_on xcode:`: Homebrew's Xcode requirement rejects a Command Line Tools-only Mac.
  depends_on macos: :sonoma
  depends_on "whisper.cpp"

  # Below macOS 26 there is no Apple speech recognition to fall back on, so the main model ships too.
  on_sequoia :or_older do
    resource "whisper-small" do
      url "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin"
      # PLACEHOLDER: replace with the file's sha256.
      sha256 "0000000000000000000000000000000000000000000000000000000000000000"
    end
  end

  # The wake-word model. models/*.bin is git-ignored, so the source tarball does not carry it.
  resource "whisper-base-en" do
    url "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin"
    sha256 "a03779c86df3323075f5e796cb2ce5029f00ec8869eee3fdfb897afe36c6d002"
  end

  def install
    # --bundle-only builds with `swift build --disable-sandbox` (SwiftPM's sandbox can't nest in Homebrew's)
    # and refuses while Jarvis runs from any version folder of this formula or from the opt link.
    system "install/install.sh", "--bundle-only", "--prefix", prefix

    (pkgshare/"models").install resource("whisper-base-en")
    (pkgshare/"models").install resource("whisper-small") if MacOS.version < :tahoe

    # Homebrew's post-install step cannot write to your home folder, so the launcher copies the models into
    # Jarvis's data home, ~/Library/Application Support/Jarvis (DEC-41)
    # (a copy, never a link, and never over a file that is already there), then opens the app.
    (bin/"jarvis").write <<~SH
      #!/bin/bash
      set -euo pipefail
      models="$HOME/Library/Application Support/Jarvis/models"
      mkdir -p "$models"
      for file in "#{opt_pkgshare}/models/"*.bin; do
        name="$(basename "$file")"
        if [ ! -f "$models/$name" ]; then
          cp "$file" "$models/$name.part"
          mv "$models/$name.part" "$models/$name"
        fi
      done
      exec open "#{opt_prefix}/Jarvis.app"
    SH
  end

  def caveats
    <<~EOS
      To open Jarvis, run:
        jarvis
      Open it with `jarvis` the first time: that run copies the whisper models into
      ~/Library/Application Support/Jarvis/models.
      Opening Jarvis.app from Finder, Spotlight or a login item skips the copy. Look for the icon in
      the menu bar.
      Speech to text: on macOS 15 and earlier, whisper.cpp with the small model installed here. On
      macOS 26 and later, Apple's on-device speech recognition; if your language isn't covered, Jarvis
      downloads a whisper model in the background.

      Notes and voice commands use Claude Code if it's installed (https://claude.com/claude-code).
      Jarvis looks for claude in Homebrew's bin folder, ~/.local/bin and ~/.claude/local, not on
      Terminal's PATH. Without it, notes use Apple's on-device model (macOS 26+, with Apple
      Intelligence on) or Ollama (about 2 GB):
        brew install ollama && brew services start ollama && ollama pull llama3.2
      With none of them, transcripts and search still work.

      Permissions:
        1. Allow microphone access when macOS asks.
        2. Screen Recording is asked for once, for call audio only. You can say no and allow it
           later from the menu.
        3. To import iPhone Voice Memos, allow Full Disk Access: System Settings > Privacy & Security >
           Full Disk Access > + (the menu has a button that opens that page). The app is at
             #{opt_prefix}/Jarvis.app
           In the file picker press Shift-Command-G (⇧⌘G), paste that path and press Return.
      Jarvis is signed on your Mac without a developer certificate. After a reinstall or upgrade macOS
      may ask for the microphone again, and Screen Recording or Full Disk Access can switch off without
      a prompt. Turn them back on from the lines in Jarvis's menu. Quit Jarvis from its menu before
      `brew upgrade` or `brew reinstall`. Upgrades build from source too, so they need Swift 6
      (macOS 14.5 or later, with Xcode 16 or Command Line Tools 16).

      The AirPods stem squeeze is experimental and off by default. Read its side effects in the
      README ("AirPods stem squeeze" under "What runs where") before you turn it on in Settings:
        https://github.com/yashMangal19/jarvis#what-runs-where

      Privacy: your audio never leaves your Mac. When Claude Code writes your notes, each hour's
      transcript text is sent to Anthropic. A voice command's words go to Claude to draft the plan
      before you say yes. With Apple's on-device model or Ollama, and no voice commands, nothing
      leaves your Mac.
      Tell people when you are recording them. Consent and local laws apply to you.

      Guide: https://yashmangal19.github.io/jarvis/guide.html
    EOS
  end

  test do
    assert_path_exists prefix/"Jarvis.app/Contents/MacOS/JarvisApp"
    system "codesign", "--verify", prefix/"Jarvis.app"
  end
end
