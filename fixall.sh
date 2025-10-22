#!/bin/bash
set -e

echo "🚀 Hustle Airdrops - Applying All Fixes and Patches"
echo "--------------------------------------------------"
# -------------------------------------
# 1️⃣ Replace page.tsx with Latest
# -------------------------------------
echo ""
echo "📥 Downloading latest page.tsx from Hustle GitHub..."

PAGE_DEST="$HOME/rl-swarm/modal-login/app/page.tsx"
curl -fsSL https://raw.githubusercontent.com/hustleairdrops/Gensyn-Advanced-Solutions/main/page.tsx -o "$PAGE_DEST"

if [ $? -eq 0 ]; then
  echo "✅ Successfully updated: page.tsx"
else
  echo "❌ Failed to download page.tsx from GitHub."
fi
# -------------------------------------
# ✅ Completion Message
# -------------------------------------
echo ""
echo "🎉 All patches and fixes have been successfully applied!"
echo "💡 Your Hustle Airdrops setup is now ready to roll. Happy hustling! 🚀"
