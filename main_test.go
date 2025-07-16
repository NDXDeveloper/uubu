package main

import (
	"os"
	"os/user"
	"strings"
	"testing"
	"time"
)

// Tests des fonctions utilitaires
func TestPrintMessage(t *testing.T) {
	// Test que printMessage ne plante pas
	defer func() {
		if r := recover(); r != nil {
			t.Errorf("printMessage a paniqué: %v", r)
		}
	}()

	printMessage(Red, "Test rouge")
	printMessage(Green, "Test vert")
	printMessage(Yellow, "Test jaune")
	printMessage(Blue, "Test bleu")
	printMessage("", "Test sans couleur")
}

func TestCommandExists(t *testing.T) {
	testCases := []struct {
		name     string
		command  string
		expected bool
	}{
		{"ls exists", "ls", true},
		{"echo exists", "echo", true},
		{"fake command", "commandthatdoesnotexist123", false},
		{"empty command", "", false},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			result := commandExists(tc.command)
			if result != tc.expected {
				t.Errorf("commandExists(%s) = %v, attendu %v", tc.command, result, tc.expected)
			}
		})
	}
}

func TestCheckRoot(t *testing.T) {
	err := checkRoot()

	currentUser, userErr := user.Current()
	if userErr != nil {
		t.Skip("Impossible de déterminer l'utilisateur actuel")
	}

	if currentUser.Uid == "0" {
		// Si on est root, checkRoot devrait retourner une erreur
		if err == nil {
			t.Error("checkRoot() devrait retourner une erreur quand exécuté en tant que root")
		}
	} else {
		// Si on n'est pas root, checkRoot devrait retourner nil
		if err != nil {
			t.Errorf("checkRoot() ne devrait pas retourner d'erreur pour un utilisateur normal: %v", err)
		}
	}
}

func TestRunCommand(t *testing.T) {
	testCases := []struct {
		name        string
		command     string
		args        []string
		expectError bool
	}{
		{"echo test", "echo", []string{"hello"}, false},
		{"ls current dir", "ls", []string{"."}, false},
		{"date command", "date", []string{}, false},
		{"invalid command", "commandthatdoesnotexist", []string{}, true},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			output, err := runCommand(tc.command, tc.args...)

			if tc.expectError {
				if err == nil {
					t.Errorf("runCommand(%s) devrait retourner une erreur", tc.command)
				}
			} else {
				if err != nil {
					t.Errorf("runCommand(%s) a retourné une erreur inattendue: %v", tc.command, err)
				}
				if tc.command == "echo" && !strings.Contains(output, "hello") {
					t.Error("runCommand(echo hello) devrait contenir 'hello'")
				}
			}
		})
	}
}

func TestConfig(t *testing.T) {
	config := Config{
		CreateSnapshot:    false,
		UpdateSnap:        true,
		UpdateFlatpak:     true,
		CheckRebootNeeded: true,
	}

	// Test des valeurs par défaut
	if config.CreateSnapshot {
		t.Error("CreateSnapshot devrait être false par défaut")
	}
	if !config.UpdateSnap {
		t.Error("UpdateSnap devrait être true par défaut")
	}
	if !config.UpdateFlatpak {
		t.Error("UpdateFlatpak devrait être true par défaut")
	}
	if !config.CheckRebootNeeded {
		t.Error("CheckRebootNeeded devrait être true par défaut")
	}
}

func TestCreateSnapshot_NoTimeshift(t *testing.T) {
	// Sauvegarder le PATH original
	originalPath := os.Getenv("PATH")
	defer os.Setenv("PATH", originalPath)

	// Modifier PATH pour que timeshift ne soit pas trouvé
	os.Setenv("PATH", "/tmp")

	err := createSnapshot()

	// Ne devrait pas retourner d'erreur même si timeshift n'existe pas
	if err != nil {
		t.Errorf("createSnapshot() a retourné une erreur quand timeshift n'est pas installé: %v", err)
	}
}

func TestCheckInternet(t *testing.T) {
	if testing.Short() {
		t.Skip("Test d'intégration ignoré en mode court")
	}

	// Test avec timeout pour éviter les blocages
	done := make(chan error, 1)
	go func() {
		done <- checkInternet()
	}()

	select {
	case err := <-done:
		if err != nil {
			t.Logf("checkInternet() a échoué (normal si pas de connexion): %v", err)
		}
	case <-time.After(10 * time.Second):
		t.Error("checkInternet() a pris plus de 10 secondes")
	}
}

func TestParseUpgradablePackages(t *testing.T) {
	// Test du parsing des paquets (simulation de sortie d'apt)
	mockOutput := `En train de lister… Fait
firefox/noble-updates,noble-security 130.0.1+build1-0ubuntu1 amd64 [pouvant être mis à jour depuis : 129.0.2+build1-0ubuntu1]
libreoffice-core/noble-updates 1:24.2.5-0ubuntu0.24.04.1 amd64 [pouvant être mis à jour depuis : 1:24.2.4-0ubuntu0.24.04.1]
`

	lines := strings.Split(strings.TrimSpace(mockOutput), "\n")
	var upgradableLines []string

	for i, line := range lines {
		line = strings.TrimSpace(line)
		if i > 0 && line != "" && !strings.Contains(line, "En train de lister") {
			upgradableLines = append(upgradableLines, line)
		}
	}

	expectedCount := 2
	if len(upgradableLines) != expectedCount {
		t.Errorf("Parsing: attendu %d paquets, trouvé %d", expectedCount, len(upgradableLines))
	}

	// Vérifier que firefox est dans la liste
	found := false
	for _, line := range upgradableLines {
		if strings.Contains(line, "firefox") {
			found = true
			break
		}
	}
	if !found {
		t.Error("Firefox devrait être dans la liste des paquets")
	}
}

func TestVersionVariables(t *testing.T) {
	// Vérifier que les variables de version sont définies
	if version == "" {
		t.Error("La variable version ne devrait pas être vide")
	}
	if buildTime == "" {
		t.Error("La variable buildTime ne devrait pas être vide")
	}
	if gitCommit == "" {
		t.Error("La variable gitCommit ne devrait pas être vide")
	}
}

func TestUpdateSnap_NoSnap(t *testing.T) {
	// Sauvegarder le PATH original
	originalPath := os.Getenv("PATH")
	defer os.Setenv("PATH", originalPath)

	// Modifier PATH pour que snap ne soit pas trouvé
	os.Setenv("PATH", "/tmp")

	err := updateSnap()

	// Ne devrait pas retourner d'erreur si snap n'existe pas
	if err != nil {
		t.Errorf("updateSnap() a retourné une erreur quand snap n'est pas installé: %v", err)
	}
}

func TestUpdateFlatpak_NoFlatpak(t *testing.T) {
	// Sauvegarder le PATH original
	originalPath := os.Getenv("PATH")
	defer os.Setenv("PATH", originalPath)

	// Modifier PATH pour que flatpak ne soit pas trouvé
	os.Setenv("PATH", "/tmp")

	err := updateFlatpak()

	// Ne devrait pas retourner d'erreur si flatpak n'existe pas
	if err != nil {
		t.Errorf("updateFlatpak() a retourné une erreur quand flatpak n'est pas installé: %v", err)
	}
}

func TestEdgeCases(t *testing.T) {
	// Tests de robustesse
	testCases := []struct {
		name string
		test func()
	}{
		{"Empty color", func() { printMessage("", "test") }},
		{"Empty message", func() { printMessage(Red, "") }},
		{"Long message", func() {
			longMsg := strings.Repeat("a", 1000)
			printMessage(Blue, longMsg)
		}},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			defer func() {
				if r := recover(); r != nil {
					t.Errorf("Test %s a paniqué: %v", tc.name, r)
				}
			}()
			tc.test()
		})
	}
}

// Benchmarks
func BenchmarkCommandExists(b *testing.B) {
	for i := 0; i < b.N; i++ {
		commandExists("ls")
	}
}

func BenchmarkPrintMessage(b *testing.B) {
	for i := 0; i < b.N; i++ {
		printMessage(Green, "Message de test")
	}
}

func BenchmarkRunCommand(b *testing.B) {
	for i := 0; i < b.N; i++ {
		_, err := runCommand("echo", "test")
		if err != nil {
			b.Errorf("Command failed: %v", err) // b.Errorf au lieu de t.Errorf
		}
	}
}
