# Makefile pour uubu
.PHONY: build test clean run help install build-arm64 build-all build-deb-arm64 package-all

# Variables
BINARY_NAME=uubu
MAIN_FILES=main.go
VERSION ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
BUILD_TIME = $(shell date -u +%Y-%m-%dT%H:%M:%SZ)
GIT_COMMIT = $(shell git rev-parse HEAD 2>/dev/null || echo "unknown")

# Flags de build avec injection des variables
LDFLAGS_BASE = -X main.version=$(VERSION) -X main.buildTime=$(BUILD_TIME) -X main.gitCommit=$(GIT_COMMIT)
LDFLAGS_RELEASE = -s -w $(LDFLAGS_BASE)

# Détection automatique de l'architecture
ARCH ?= $(shell uname -m)
ifeq ($(ARCH),x86_64)
    GOARCH_HOST = amd64
else ifeq ($(ARCH),aarch64)
    GOARCH_HOST = arm64
else ifeq ($(ARCH),arm64)
    GOARCH_HOST = arm64
else
    GOARCH_HOST = amd64
endif

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

build: ## Compiler le binaire (architecture hôte)
	@echo "🔨 Compilation pour $(GOARCH_HOST)..."
	go build -ldflags "$(LDFLAGS_BASE)" -o $(BINARY_NAME) $(MAIN_FILES)

build-release: ## Compiler le binaire optimisé (release) pour l'architecture hôte
	@echo "🔨 Compilation release pour $(GOARCH_HOST)..."
	go build -ldflags "$(LDFLAGS_RELEASE)" -trimpath -o $(BINARY_NAME) $(MAIN_FILES)
	cp $(BINARY_NAME) $(BINARY_NAME)-linux-$(GOARCH_HOST)

build-amd64: ## Compiler spécifiquement pour AMD64
	@echo "🔨 Compilation pour AMD64..."
	GOOS=linux GOARCH=amd64 go build -ldflags "$(LDFLAGS_RELEASE)" -trimpath -o $(BINARY_NAME)-linux-amd64 $(MAIN_FILES)

build-arm64: ## Compiler spécifiquement pour ARM64
	@echo "🔨 Compilation pour ARM64..."
	GOOS=linux GOARCH=arm64 go build -ldflags "$(LDFLAGS_RELEASE)" -trimpath -o $(BINARY_NAME)-linux-arm64 $(MAIN_FILES)

build-all: build-amd64 build-arm64 ## Compiler pour toutes les architectures
	@echo "✅ Compilation terminée pour toutes les architectures"
	@ls -la $(BINARY_NAME)-linux-*

build-deb: install-nfpm build-amd64 ## Construire le package .deb AMD64
	@echo "🔨 Construction du package .deb AMD64..."
	@cp $(BINARY_NAME)-linux-amd64 $(BINARY_NAME)
	@VERSION=$(VERSION) nfpm package --config nfpm.yaml --packager deb --target $(BINARY_NAME)-$(VERSION)-amd64.deb
	@echo "✅ Package .deb AMD64 créé"
	@chmod a+r $(BINARY_NAME)-$(VERSION)-amd64.deb
	@ls -la *.deb
	@rm $(BINARY_NAME)


build-deb-arm64: install-nfpm build-arm64 ## Construire le package .deb ARM64
	@echo "🔨 Construction du package .deb ARM64..."
	@cp $(BINARY_NAME)-linux-arm64 $(BINARY_NAME)
	@# Créer un fichier nfpm temporaire pour ARM64
	@sed 's/amd64/arm64/g' nfpm.yaml > nfpm-arm64.yaml
	@VERSION=$(VERSION) nfpm package --config nfpm-arm64.yaml --packager deb --target $(BINARY_NAME)-$(VERSION)-arm64.deb
	@rm -f nfpm-arm64.yaml
	@echo "✅ Package .deb ARM64 créé"
	@chmod a+r $(BINARY_NAME)-$(VERSION)-arm64.deb
	@ls -la *.deb
	@rm $(BINARY_NAME)

build-deb-all: build-deb build-deb-arm64 ## Construire les packages .deb pour toutes les architectures
	@echo "✅ Tous les packages .deb créés"
	@ls -la *.deb

version: ## Afficher la version qui sera compilée
	@echo "Version: $(VERSION)"
	@echo "Build time: $(BUILD_TIME)"
	@echo "Git commit: $(GIT_COMMIT)"
	@echo "Host architecture: $(GOARCH_HOST)"

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
test: check-locales ## Exécuter les tests
	@echo "🧪 Exécution des tests..."
	go test -v ./...

# Tests avec plus de détails
test-verbose: ## Tests détaillés
	@echo "🔍 Tests détaillés..."
	go test -v -race ./...

# Tests rapides (sans intégration)
test-short: ## Tests rapides
	@echo "⚡ Tests rapides..."
	go test -short ./...

# Couverture de code
test-coverage: ## Analyse de couverture
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
	rm -f $(BINARY_NAME)-linux-*
	rm -f *.deb
	rm -f coverage.out coverage.html
	rm -f *.csv
	rm -f nfpm-arm64.yaml
	rm -rf dist/

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

# Package avec toutes les langues et architectures
package: build-all ## Créer un package avec toutes les langues et architectures
	@echo "📦 Création des packages..."
	@mkdir -p dist/tmp-amd64 dist/tmp-arm64
	@# Package AMD64
	@cp $(BINARY_NAME)-linux-amd64 dist/tmp-amd64/$(BINARY_NAME)
	@cp -r locales dist/tmp-amd64/
	@cp README.md dist/tmp-amd64/ 2>/dev/null || echo "README.md non trouvé"
	@cp LICENSE dist/tmp-amd64/ 2>/dev/null || echo "LICENSE non trouvé"
	@tar -czf dist/$(BINARY_NAME)-$(VERSION)-linux-amd64.tar.gz -C dist/tmp-amd64 .
	@# Package ARM64
	@cp $(BINARY_NAME)-linux-arm64 dist/tmp-arm64/$(BINARY_NAME)
	@cp -r locales dist/tmp-arm64/
	@cp README.md dist/tmp-arm64/ 2>/dev/null || echo "README.md non trouvé"
	@cp LICENSE dist/tmp-arm64/ 2>/dev/null || echo "LICENSE non trouvé"
	@tar -czf dist/$(BINARY_NAME)-$(VERSION)-linux-arm64.tar.gz -C dist/tmp-arm64 .
	@# Nettoyage des dossiers temporaires
	@rm -rf dist/tmp-amd64 dist/tmp-arm64
	@echo "✅ Packages créés:"
	@ls -la dist/$(BINARY_NAME)-$(VERSION)-linux-*.tar.gz

package-all: package build-deb-all ## Créer tous les packages (tar.gz + deb) pour toutes les architectures
	@echo "📦 Déplacement des .deb vers dist/..."
	@mkdir -p dist
	@mv *.deb dist/ 2>/dev/null || echo "Aucun fichier .deb à déplacer"
	@echo "✅ Tous les packages créés dans dist/:"
	@ls -la dist/

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
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# Par défaut, afficher l'aide
.DEFAULT_GOAL := help
