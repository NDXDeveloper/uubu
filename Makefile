# Makefile pour uubu
.PHONY: build test clean run help install

# Variables
BINARY_NAME=uubu
MAIN_FILES=main.go
VERSION ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
BUILD_TIME = $(shell date -u +%Y-%m-%dT%H:%M:%SZ)
GIT_COMMIT = $(shell git rev-parse HEAD 2>/dev/null || echo "unknown")

# Flags de build avec injection des variables
LDFLAGS_BASE = -X main.version=$(VERSION) -X main.buildTime=$(BUILD_TIME) -X main.gitCommit=$(GIT_COMMIT)
LDFLAGS_RELEASE = -s -w $(LDFLAGS_BASE)

# Commandes principales
check-nfpm: ## Vérifier si nfpm est installé
	@if ! command -v nfpm >/dev/null 2>&1; then \
		echo "❌ nfpm n'est pas installé!"; \
		echo "📦 Installation avec Go: go install github.com/goreleaser/nfpm/v2/cmd/nfpm@latest"; \
		echo "📦 Ou avec apt via le repo: https://github.com/goreleaser/nfpm/releases/ "; \
		exit 1; \
	fi
	@echo "✅ nfpm est installé"

# Construction du package .deb
install-nfpm: ## Installer nfpm automatiquement
	@echo "🔍 Vérification de nfpm..."
	@if command -v nfpm >/dev/null 2>&1; then \
		echo "✅ nfpm est déjà installé: $$(nfpm version)"; \
	else \
		echo "📦 Installation de nfpm..."; \
		if command -v go >/dev/null 2>&1; then \
			echo "🔧 Installation via Go..."; \
			go install github.com/goreleaser/nfpm/v2/cmd/nfpm@latest; \
			if command -v nfpm >/dev/null 2>&1; then \
				echo "✅ nfpm installé avec succès via Go"; \
			else \
				echo "⚠️  nfpm installé mais pas dans le PATH. Ajoutez $$(go env GOPATH)/bin à votre PATH"; \
				echo "   export PATH=\$$PATH:$$(go env GOPATH)/bin"; \
			fi; \
		else \
			wget https://github.com/goreleaser/nfpm/releases/download/v2.43.0/nfpm_2.43.0_amd64.deb ; \
			sudo dpkg -i nfpm_2.43.0_amd64.deb ; \
		fi; \
		if command -v nfpm >/dev/null 2>&1; then \
			echo "✅ nfpm est maintenant disponible: $$(nfpm version)"; \
		else \
			echo "❌ Problème lors de l'installation de nfpm"; \
			exit 1; \
		fi; \
	fi


build-deb: install-nfpm ## Construire le package .deb
	@echo "🔨 Construction du package .deb..."
	@VERSION=$(VERSION) nfpm package --config nfpm.yaml --packager deb --target uubu-amd64.deb
	@echo "✅ Package .deb créé dans le dossier dist/"
	@chmod a+r uubu-amd64.deb
	@ls -la *.deb


build: ## Compiler le binaire
	#go build -o $(BINARY_NAME) $(MAIN_FILES)
	go build -ldflags "$(LDFLAGS_BASE)" -o uubu main.go

build-release: ## Compiler le binaire optimisé (release)
	go build -ldflags "$(LDFLAGS_RELEASE)" -trimpath -o uubu main.go
	cp uubu uubu-linux-amd64

version: ## Afficher la version qui sera compilée
	@echo "Version: $(VERSION)"
	@echo "Build time: $(BUILD_TIME)"
	@echo "Git commit: $(GIT_COMMIT)"

# Vérification des fichiers de langues
check-locales: ## Vérifier les fichiers de langues
	@echo "🌍 Vérification des fichiers de langues..."
	@if [ ! -d "locales" ]; then \
		echo "❌ Dossier 'locales' manquant!"; \
		exit 1; \
	fi
	@for lang in en fr de es; do \
		if [ ! -f "locales/$$lang.json" ]; then \
			echo "❌ Fichier locales/$$lang.json manquant!"; \
			exit 1; \
		else \
			echo "✅ locales/$$lang.json trouvé"; \
		fi; \
	done
	@echo "🌍 Tous les fichiers de langues sont présents"

# Validation JSON des fichiers de langues
validate-locales: ## Valider la syntaxe JSON des fichiers de langues
	@echo "🔍 Validation JSON des fichiers de langues..."
	@for file in locales/*.json; do \
		echo "Validation de $$file..."; \
		if command -v jq >/dev/null 2>&1; then \
			jq empty "$$file" && echo "✅ $$file valide" || (echo "❌ $$file invalide" && exit 1); \
		else \
			python3 -m json.tool "$$file" >/dev/null && echo "✅ $$file valide" || (echo "❌ $$file invalide" && exit 1); \
		fi; \
	done

# Tests avec différentes langues
test-langs: build ## Tester avec différentes langues
	@echo "🧪 Test avec différentes langues..."
	@for lang in en fr de es; do \
		echo "Test avec langue: $$lang"; \
		UUBU_LANG=$$lang ./$(BINARY_NAME) --version; \
	done


# Tests de base
test:
	check-locales
	@echo "🧪 Exécution des tests..."
	go test -v ./...

# Tests avec plus de détails
test-verbose:
	@echo "🔍 Tests détaillés..."
	go test -v -race ./...

# Tests rapides (sans intégration)
test-short:
	@echo "⚡ Tests rapides..."
	go test -short ./...

# Couverture de code
test-coverage:
	@echo "📊 Analyse de couverture..."
	go test -coverprofile=coverage.out ./...
	go tool cover -html=coverage.out -o coverage.html
	@echo "📈 Rapport de couverture généré: coverage.html"

run: build ## Compiler et lancer l'application
	./$(BINARY_NAME)

install: build ## Installer le binaire dans /usr/local/bin
	@echo "📦 Installation..."
	sudo cp $(BINARY_NAME) /usr/local/bin/
	@echo "✅ $(BINARY_NAME) installé dans /usr/local/bin/"

uninstall: ## Désinstaller le binaire
	@echo "🗑️  Désinstallation..."
	sudo rm -f /usr/local/bin/$(BINARY_NAME)
	@echo "✅ $(BINARY_NAME) désinstallé"

clean: ## Nettoyer les fichiers générés
	@echo "🧹 Nettoyage..."
	rm -f $(BINARY_NAME)
	rm -f coverage.out coverage.html
	rm -f *.csv

# Commandes de développement
dev: ## Mode développement avec rebuild automatique
	@echo "🔄 Mode développement - Ctrl+C pour arrêter"
	@while inotifywait -e modify *.go locales/*.json 2>/dev/null; do \
		make build && echo "✅ Rebuild terminé"; \
	done

lint: ## Vérification du code
	@echo "🔍 Vérification du code..."
	go fmt ./...
	go vet ./...
	@make validate-locales

bench: ## Benchmarks de performance
	@echo "⏱️  Benchmarks..."
	go test -bench=. -benchmem ./...


check: ## Vérification complète avant commit
	@echo "🔄 Vérifications complètes..."
	make validate-locales
	make lint
	make test-short
	make test-langs
	@echo "✅ Vérifications terminées - prêt pour commit!"

# Nouvelle langue
new-lang: ## Créer un template pour une nouvelle langue (usage: make new-lang LANG=it)
	@if [ -z "$(LANG)" ]; then \
		echo "❌ Usage: make new-lang LANG=code_langue (ex: make new-lang LANG=it)"; \
		exit 1; \
	fi
	@if [ -f "locales/$(LANG).json" ]; then \
		echo "❌ Le fichier locales/$(LANG).json existe déjà!"; \
		exit 1; \
	fi
	@echo "🌍 Création du template pour la langue: $(LANG)"
	@cp locales/en.json locales/$(LANG).json
	@echo "✅ Template créé: locales/$(LANG).json"
	@echo "📝 Éditez maintenant ce fichier pour traduire les messages"

# Info sur les langues supportées
langs: ## Afficher les langues supportées
	@echo "🌍 Langues supportées:"
	@for file in locales/*.json; do \
		lang=$$(basename "$$file" .json); \
		echo "  - $$lang"; \
	done

# Package avec toutes les langues
package: build ## Créer un package avec toutes les langues
	@echo "📦 Création du package..."
	@mkdir -p dist
	@cp $(BINARY_NAME) dist/
	@cp -r locales dist/
	@cp README.md dist/
	@cp LICENSE dist/
	@tar -czf dist/$(BINARY_NAME)-$(VERSION)-linux-amd64.tar.gz -C dist .
	@echo "✅ Package créé: dist/$(BINARY_NAME)-$(VERSION)-linux-amd64.tar.gz"

# Test de la structure des fichiers de locales
test-locales-structure: ## Tester la structure et cohérence des fichiers de locales
# Test de la structure des fichiers de locales
test-locales-structure: ## Tester la structure et cohérence des fichiers de locales
	@echo "🧪 Test de la structure des fichiers de locales..."
	@if [ ! -d "locales" ]; then \
		echo "❌ Le dossier 'locales' n'existe pas!"; \
		exit 1; \
	fi
	@echo "✅ Dossier 'locales' trouvé"
	@if [ ! -f "locales/en.json" ]; then \
		echo "❌ Le fichier locales/en.json n'existe pas!"; \
		exit 1; \
	fi
	@echo "✅ Fichier locales/en.json trouvé"
	@echo "🔍 Validation JSON de en.json..."
	@if command -v jq >/dev/null 2>&1; then \
		if ! jq empty "locales/en.json" 2>/dev/null; then \
			echo "❌ locales/en.json n'est pas un JSON valide!"; \
			exit 1; \
		fi; \
	else \
		if ! python3 -m json.tool "locales/en.json" >/dev/null 2>&1; then \
			echo "❌ locales/en.json n'est pas un JSON valide!"; \
			exit 1; \
		fi; \
	fi
	@echo "✅ locales/en.json est un JSON valide"
	@echo "🔍 Analyse de la structure des fichiers..."
	@if command -v jq >/dev/null 2>&1; then \
		EN_KEYS_COUNT=$$(jq -r 'keys | length' "locales/en.json"); \
		EN_KEYS=$$(jq -r 'keys | join(" ")' "locales/en.json"); \
		echo "📊 Fichier de référence en.json contient $$EN_KEYS_COUNT champs"; \
		for file in locales/*.json; do \
			filename=$$(basename "$$file"); \
			if [ "$$filename" != "en.json" ]; then \
				echo "🔍 Vérification de $$filename..."; \
				if ! jq empty "$$file" 2>/dev/null; then \
					echo "❌ $$filename n'est pas un JSON valide!"; \
					exit 1; \
				fi; \
				CURRENT_KEYS_COUNT=$$(jq -r 'keys | length' "$$file"); \
				CURRENT_KEYS=$$(jq -r 'keys | join(" ")' "$$file"); \
				if [ "$$CURRENT_KEYS_COUNT" -ne "$$EN_KEYS_COUNT" ]; then \
					echo "❌ $$filename contient $$CURRENT_KEYS_COUNT champs, mais en.json en contient $$EN_KEYS_COUNT!"; \
					exit 1; \
				fi; \
				if [ "$$CURRENT_KEYS" != "$$EN_KEYS" ]; then \
					echo "❌ $$filename ne contient pas les mêmes champs que en.json!"; \
					echo "   Champs attendus: $$EN_KEYS"; \
					echo "   Champs trouvés:  $$CURRENT_KEYS"; \
					exit 1; \
				fi; \
				echo "✅ $$filename est valide ($$CURRENT_KEYS_COUNT champs)"; \
			fi; \
		done; \
	else \
		EN_KEYS_COUNT=$$(python3 -c "import json; data=json.load(open('locales/en.json')); print(len(data.keys()))"); \
		EN_KEYS=$$(python3 -c "import json; data=json.load(open('locales/en.json')); print(' '.join(sorted(data.keys())))"); \
		echo "📊 Fichier de référence en.json contient $$EN_KEYS_COUNT champs"; \
		for file in locales/*.json; do \
			filename=$$(basename "$$file"); \
			if [ "$$filename" != "en.json" ]; then \
				echo "🔍 Vérification de $$filename..."; \
				if ! python3 -m json.tool "$$file" >/dev/null 2>&1; then \
					echo "❌ $$filename n'est pas un JSON valide!"; \
					exit 1; \
				fi; \
				CURRENT_KEYS_COUNT=$$(python3 -c "import json; data=json.load(open('$$file')); print(len(data.keys()))"); \
				CURRENT_KEYS=$$(python3 -c "import json; data=json.load(open('$$file')); print(' '.join(sorted(data.keys())))"); \
				if [ "$$CURRENT_KEYS_COUNT" -ne "$$EN_KEYS_COUNT" ]; then \
					echo "❌ $$filename contient $$CURRENT_KEYS_COUNT champs, mais en.json en contient $$EN_KEYS_COUNT!"; \
					exit 1; \
				fi; \
				if [ "$$CURRENT_KEYS" != "$$EN_KEYS" ]; then \
					echo "❌ $$filename ne contient pas les mêmes champs que en.json!"; \
					echo "   Champs attendus: $$EN_KEYS"; \
					echo "   Champs trouvés:  $$CURRENT_KEYS"; \
					exit 1; \
				fi; \
				echo "✅ $$filename est valide ($$CURRENT_KEYS_COUNT champs)"; \
			fi; \
		done; \
	fi
	@echo "🎉 Tous les fichiers de locales sont structurellement cohérents!"

help: ## Afficher cette aide
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

# Par défaut, afficher l'aide
.DEFAULT_GOAL := help

