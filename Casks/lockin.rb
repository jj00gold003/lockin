# Template Homebrew Cask for LockIn.
# Not yet submitted to homebrew-cask: requires a real release tag, dmg, and
# sha256. Before submitting, replace the repo URLs if needed, uncomment the
# sha256 line with the real digest from:
#   shasum -a 256 LockIn-0.1.0.dmg
cask "lockin" do
  version "0.1.0"
  # TODO: compute with `shasum -a 256 LockIn-0.1.0.dmg` after first release
  # sha256 "0000000000000000000000000000000000000000000000000000000000000000"

  url "https://github.com/andy0332hk/lockin/releases/download/v#{version}/LockIn-#{version}.dmg"
  name "LockIn"
  desc "Focus timer, Pomodoro, tasks, habits and distraction blocking"
  homepage "https://github.com/andy0332hk/lockin"

  app "LockIn.app"
end
