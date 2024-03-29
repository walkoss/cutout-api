# https://raw.githubusercontent.com/EnMarche/en-marche.fr/master/Makefile
FIG=docker-compose
RUN=$(FIG) run --rm app
EXEC=$(FIG) exec app
CONSOLE=bin/console

.DEFAULT_GOAL := help
.PHONY: help start stop reset db db-diff db-migrate db-rollback db-load clear clean test tu tf build up perm deps cc generate-jwt-keys

help:
	@fgrep -h "##" $(MAKEFILE_LIST) | fgrep -v fgrep | sed -e 's/\\$$//' | sed -e 's/##//'


##
## Project setup
##---------------------------------------------------------------------------

start:          	## Install and start the project
start: build up app/config/parameters.yml generate-jwt-keys db perm

stop:           	## Remove docker containers
	$(FIG) kill

reset:          	## Reset the whole project
reset: stop start

clear:          	## Remove all the cache, the logs, the sessions and the built assets
clear: perm
	-$(EXEC) php bin/console cache:clear
	-$(EXEC) rm -rf var/cache/*
	-$(EXEC) rm -rf var/sessions/*
	rm -rf var/logs/*

clean:          	## Clear and remove dependencies
clean: clear
	rm -rf vendor

cc:             	## Clear the cache in dev env
cc:
	$(RUN) $(CONSOLE) cache:clear

generate-jwt-keys:	## Generate JWT keys
generate-jwt-keys:
ifeq (, $(shell which openssl))
$(error "Unable to generate keys (needs OpenSSL)")
endif
	mkdir -p var/jwt
	openssl genrsa -passout pass:cutoutapi -out var/jwt/private.pem -aes256 4096
	openssl rsa -passin pass:cutoutapi -pubout -in var/jwt/private.pem -out var/jwt/public.pem
	@echo "\033[32mRSA key pair successfully generated\033[39m"


##
## Database
##---------------------------------------------------------------------------

db:             	## Reset the database and load fixtures
db: vendor
	$(RUN) php -r "for(;;){if(@fsockopen('db',3306)){break;}}" # Wait for MySQL
	$(RUN) $(CONSOLE) doctrine:database:drop --force --if-exists
	$(RUN) $(CONSOLE) doctrine:database:create --if-not-exists
	$(RUN) $(CONSOLE) doctrine:migrations:migrate -n
	$(RUN) $(CONSOLE) doctrine:fixtures:load -n

db-diff:        	## Generate a migration by comparing your current database to your mapping information
db-diff: vendor
	$(RUN) $(CONSOLE) doctrine:migration:diff

db-migrate:     	## Migrate database schema to the latest available version
db-migrate: vendor
	$(RUN) $(CONSOLE) doctrine:migration:migrate -n

db-rollback:    	## Rollback the latest executed migration
db-rollback: vendor
	$(RUN) $(CONSOLE) d:m:e --down $(shell $(RUN) $(CONSOLE) d:m:l) -n

db-load:        	## Reset the database fixtures
db-load: vendor
	$(RUN) $(CONSOLE) doctrine:fixtures:load -n


##
## Tests
##---------------------------------------------------------------------------

test:           	## Run the PHP tests
test: vendor
	$(RUN) vendor/bin/phpunit

tu:             	## Run the PHP unit tests
tu: vendor
	$(RUN) vendor/bin/phpunit --exclude-group functional

tf:             	## Run the PHP functional tests
tf: vendor
	$(RUN) vendor/bin/phpunit --group functional


##
## Dependencies
##---------------------------------------------------------------------------

deps:           	## Install the project PHP dependencies
deps: vendor


# Internal rules

build:
	$(FIG) build

up:
	$(FIG) up -d

perm:
	-$(EXEC) chmod 777 -R var

# Rules from files

vendor: composer.lock
	@$(RUN) composer install

composer.lock: composer.json
	@echo compose.lock is not up to date.

app/config/parameters.yml: app/config/parameters.yml.dist
	@$(RUN) composer run-script post-install-cmd