web: mise watch -w gen/proto/ruby -w Gemfile.lock -o restart --debounce 2s --no-vcs-ignore server
vite: bin/vite dev
ui: cd ui && exec trustless exec sponsor-app node_modules/.bin/vite
proto: mise watch gen:proto
