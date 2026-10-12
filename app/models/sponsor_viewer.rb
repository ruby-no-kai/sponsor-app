# typed: strict
# frozen_string_literal: true

# Whoever is using the sponsor area, as their session describes them. `email` is nil and
# `sponsorships` empty when no sponsor contact is signed in.
SponsorViewer = Data.define(:email, :staff, :sponsorships, :locale)
