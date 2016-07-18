server:
	bundle exec rake webpack:run& bundle exec thin start --port=3001
run:
	bundle exec thin start --port=3001
test:
	bundle exec rspec && bundle exec rake rspec:browser
