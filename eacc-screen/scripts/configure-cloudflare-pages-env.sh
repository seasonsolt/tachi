#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="${PROJECT_NAME:-eacc-screen}"
DEFAULT_CONTACT_TO="contact@e-acc.ai"
DEFAULT_CONTACT_FROM="EACC <contact@e-acc.ai>"

printf "Cloudflare Account ID: "
read -r CLOUDFLARE_ACCOUNT_ID

printf "Cloudflare API Token: "
stty -echo
read -r CLOUDFLARE_API_TOKEN
stty echo
printf "\n"

printf "Resend API Key: "
stty -echo
read -r RESEND_API_KEY
stty echo
printf "\n"

printf "Contact recipient [%s]: " "$DEFAULT_CONTACT_TO"
read -r CONTACT_TO
CONTACT_TO="${CONTACT_TO:-$DEFAULT_CONTACT_TO}"

printf "Contact sender [%s]: " "$DEFAULT_CONTACT_FROM"
read -r CONTACT_FROM
CONTACT_FROM="${CONTACT_FROM:-$DEFAULT_CONTACT_FROM}"

export CLOUDFLARE_ACCOUNT_ID
export CLOUDFLARE_API_TOKEN

put_secret() {
  local name="$1"
  local value="$2"
  printf "%s" "$value" | pnpm exec wrangler pages secret put "$name" --project-name "$PROJECT_NAME"
}

printf "\nConfiguring Cloudflare Pages project: %s\n" "$PROJECT_NAME"
put_secret RESEND_API_KEY "$RESEND_API_KEY"
put_secret CONTACT_TO "$CONTACT_TO"
put_secret CONTACT_FROM "$CONTACT_FROM"

printf "\nDone. Secrets configured for %s.\n" "$PROJECT_NAME"
