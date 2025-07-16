package main

import (
	"bufio"
	"embed"
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"net"
	"os"
	"os/exec"
	"os/user"
	"strings"
	"time"
)

// ANSI colors for display
const (
	Red    = "\033[0;31m"
	Green  = "\033[0;32m"
	Yellow = "\033[1;33m"
	Blue   = "\033[0;34m"
	NC     = "\033[0m" // No Color
)

var (
	version   = "dev version"
	buildTime = "unknown"
	gitCommit = "unknown"

	// Global variable for language and messages
	currentLang = "en"
	messages    = make(map[string]string)
)

// Embed language files into the binary
//
//go:embed locales/*.json
var localesFS embed.FS

type Config struct {
	CreateSnapshot    bool
	UpdateSnap        bool
	UpdateFlatpak     bool
	CheckRebootNeeded bool
}

// loadLanguage loads messages for a given language
func loadLanguage(lang string) error {
	filename := fmt.Sprintf("locales/%s.json", lang)

	data, err := localesFS.ReadFile(filename)
	if err != nil {
		// Fallback to English if the language does not exist
		if lang != "en" {
			return loadLanguage("en")
		}
		return fmt.Errorf("impossible de charger la langue par défaut: %v", err)
	}

	var langMessages map[string]string
	if err := json.Unmarshal(data, &langMessages); err != nil {
		return fmt.Errorf("erreur de parsing JSON pour %s: %v", lang, err)
	}

	messages = langMessages
	currentLang = lang
	return nil
}

// detectLanguage detects the system language
func detectLanguage() string {
	// Priority: UUBU_LANG environment variable
	if lang := os.Getenv("UUBU_LANG"); lang != "" {
		return lang
	}

	// System environment variables
	envVars := []string{"LANG", "LANGUAGE", "LC_ALL", "LC_MESSAGES"}

	for _, env := range envVars {
		if lang := os.Getenv(env); lang != "" {
			// Extract the language code (ex: "fr_FR.UTF-8" -> "fr")
			if len(lang) >= 2 {
				langCode := strings.ToLower(lang[:2])
				// Check if the language file exists
				filename := fmt.Sprintf("locales/%s.json", langCode)
				if _, err := localesFS.ReadFile(filename); err == nil {
					return langCode
				}
			}
		}
	}

	// Default: English
	return "en"
}

// getMessage retrieves a message in the current language
func getMessage(key string, args ...interface{}) string {
	if msg, exists := messages[key]; exists {
		// Replace literal escapes with real characters
		msg = strings.ReplaceAll(msg, "\\n", "\n")
		msg = strings.ReplaceAll(msg, "\\t", "\t")

		if len(args) > 0 {
			return fmt.Sprintf(msg, args...)
		}
		return msg
	}
	return fmt.Sprintf("[MISSING: %s]", key)
}

// printMessage displays a message with a given color
func printMessage(color, message string) {
	fmt.Printf("%s%s%s\n", color, message, NC)
}

// checkRoot checks if the user is root
func checkRoot() error {
	currentUser, err := user.Current()
	if err != nil {
		return fmt.Errorf("impossible de déterminer l'utilisateur actuel: %v", err)
	}

	if currentUser.Uid == "0" {
		printMessage(Red, getMessage("no_root"))
		printMessage(Yellow, getMessage("use_sudo"))
		return fmt.Errorf("exécution en tant que root interdite")
	}

	return nil
}

// checkInternet checks the internet connection
func checkInternet() error {
	printMessage(Blue, getMessage("checking_internet"))

	conn, err := net.DialTimeout("tcp", "google.com:80", 3*time.Second)
	if err != nil {
		printMessage(Red, getMessage("internet_error"))
		return err
	}
	defer conn.Close()

	printMessage(Green, getMessage("internet_ok"))
	return nil
}

// createSnapshot creates a restore point with Timeshift
func createSnapshot() error {
	if !commandExists("timeshift") {
		printMessage(Yellow, getMessage("timeshift_missing"))
		return nil
	}

	printMessage(Blue, getMessage("creating_snapshot"))

	comment := getMessage("before_update", time.Now().Format("2006-01-02 15:04"))
	// Validation de sécurité : s'assurer que le commentaire ne contient pas de caractères dangereux
	if strings.ContainsAny(comment, ";|&`$(){}[]<>") {
		comment = "System update snapshot - " + time.Now().Format("2006-01-02 15:04")
	}
	cmd := exec.Command("sudo", "timeshift", "--create", "--comments", comment, "--scripted") // #nosec G204 -- comment validated and from controlled locale files

	if err := cmd.Run(); err != nil {
		printMessage(Yellow, getMessage("snapshot_failed"))
		return err
	}

	printMessage(Green, getMessage("snapshot_success"))
	return nil
}

// runCommand executes a command and returns its output
func runCommand(name string, args ...string) (string, error) {
	cmd := exec.Command(name, args...)
	output, err := cmd.CombinedOutput()
	return string(output), err
}

// commandExists checks if a command exists
func commandExists(cmd string) bool {
	_, err := exec.LookPath(cmd)
	return err == nil
}

// updateSystem performs the main system update
func updateSystem(distUpgrade bool) error {
	printMessage(Blue, getMessage("update_start"))

	// Update the package list
	printMessage(Blue, getMessage("update_packages"))
	if _, err := runCommand("sudo", "apt", "update"); err != nil {
		printMessage(Red, getMessage("update_error"))
		return err
	}

	// Checking for packages to update
	output, err := runCommand("apt", "list", "--upgradable")
	if err != nil {
		printMessage(Red, getMessage("check_packages"))
		return err
	}

	lines := strings.Split(strings.TrimSpace(output), "\n")
	// Filter empty lines and the header line
	var upgradableLines []string
	for i, line := range lines {
		line = strings.TrimSpace(line)
		// Ignore the first line (header) and empty lines
		if i > 0 && line != "" && !strings.Contains(line, "En train de lister") && !strings.Contains(line, "Listing") {
			upgradableLines = append(upgradableLines, line)
		}
	}

	upgradableCount := len(upgradableLines)

	if upgradableCount > 0 {
		printMessage(Yellow, getMessage("packages_count", upgradableCount))
		printMessage(Blue, getMessage("packages_list"))

		// Display packages (limit to 10 for display)
		displayCount := upgradableCount
		/*if displayCount > 10 {
			displayCount = 10
		}*/

		for i := 0; i < displayCount; i++ {
			fmt.Println(upgradableLines[i])
		}

		/*if upgradableCount > 10 {
			fmt.Printf("... %s %d %s\n", getMessage("and"), upgradableCount-10, getMessage("other_packages"))
		}*/
		fmt.Println()
	} else {
		printMessage(Green, getMessage("no_packages"))
		return nil
	}

	// Package updates
	printMessage(Blue, getMessage("installing_updates"))
	if _, err := runCommand("sudo", "apt", "upgrade", "-y"); err != nil {
		printMessage(Red, getMessage("install_error"))
		return err
	}

	// Simple upgrade
	/*printMessage(Blue, getMessage("upgrade"))
	if _, err := runCommand("sudo", "apt", "upgrade", "-y"); err != nil {
		printMessage(Yellow, getMessage("dist_error"))
	}*/

	if distUpgrade {
		// Distribution upgrade
		printMessage(Blue, getMessage("dist_upgrade"))
		if _, err := runCommand("sudo", "apt", "dist-upgrade", "-y"); err != nil {
			printMessage(Yellow, getMessage("dist_error"))
		}
	} else {
		// Simple upgrade
		printMessage(Blue, getMessage("upgrade"))
		if _, err := runCommand("sudo", "apt", "upgrade", "-y"); err != nil {
			printMessage(Yellow, getMessage("dist_error"))
		}
	}

	// Clean up obsolete packages
	printMessage(Blue, getMessage("removing_obsolete"))
	if _, err := runCommand("sudo", "apt", "autoremove", "-y"); err != nil {
		printMessage(Yellow, getMessage("autoremove_error"))
	}

	// Cache cleanup
	printMessage(Blue, getMessage("cleaning_cache"))
	if _, err := runCommand("sudo", "apt", "autoclean"); err != nil {
		printMessage(Yellow, getMessage("autoclean_error"))
	}

	printMessage(Green, getMessage("update_finished"))
	return nil
}

// updateSnap updates Snap packages
func updateSnap() error {
	if !commandExists("snap") {
		printMessage(Yellow, getMessage("snap_missing"))
		return nil
	}

	printMessage(Blue, getMessage("updating_snap"))
	if _, err := runCommand("sudo", "snap", "refresh"); err != nil {
		printMessage(Yellow, getMessage("snap_error"))
		return err
	}

	printMessage(Green, getMessage("snap_updated"))
	return nil
}

// updateFlatpak updates Flatpak packages
func updateFlatpak() error {
	if !commandExists("flatpak") {
		printMessage(Yellow, getMessage("flatpak_missing"))
		return nil
	}

	printMessage(Blue, getMessage("updating_flatpak"))
	if _, err := runCommand("flatpak", "update", "-y"); err != nil {
		printMessage(Yellow, getMessage("flatpak_error"))
		return err
	}

	printMessage(Green, getMessage("flatpak_updated"))
	return nil
}

// checkReboot checks if a reboot is necessary
func checkReboot() error {
	if _, err := os.Stat("/var/run/reboot-required"); os.IsNotExist(err) {
		printMessage(Green, getMessage("no_reboot"))
		return nil
	}

	printMessage(Yellow, getMessage("reboot_required"))
	printMessage(Yellow, getMessage("reboot_message"))

	// Display the affected packages if the file exists
	if data, err := os.ReadFile("/var/run/reboot-required.pkgs"); err == nil {
		printMessage(Blue, getMessage("affected_packages"))
		fmt.Print(string(data))
	}

	fmt.Print(getMessage("reboot_prompt"))
	reader := bufio.NewReader(os.Stdin)
	response, err := reader.ReadString('\n')
	if err != nil {
		return err
	}

	response = strings.TrimSpace(strings.ToLower(response))
	// Support multiple languages for yes/no
	yesAnswers := strings.Split(getMessage("yes_answers"), ",")
	for _, yes := range yesAnswers {
		if response == strings.TrimSpace(yes) {
			printMessage(Blue, getMessage("rebooting"))
			return exec.Command("sudo", "reboot").Run()
		}
	}

	printMessage(Yellow, getMessage("reboot_later"))
	return nil
}

// showVersion only displays version information
func showVersion() {
	fmt.Printf("uubu %s\n", version)
	fmt.Printf("Build time: %s\n", buildTime)
	fmt.Printf("Git commit: %s\n", gitCommit)
	fmt.Printf("%s\n", getMessage("license"))
	fmt.Printf("Language: %s\n", currentLang)
}

// showHelp displays help
func showHelp() {
	fmt.Printf("%s\n\n%s:\n",
		getMessage("help_description"),
		getMessage("description"))

	// Treat long description with indentation
	descLong := getMessage("help_desc_long")
	lines := strings.Split(descLong, "\n")
	for _, line := range lines {
		fmt.Printf("  %s\n", line)
	}
	fmt.Println()

	fmt.Printf("%s\n\n", getMessage("help_usage", os.Args[0]))

	fmt.Printf("%s\n", getMessage("help_options"))
	fmt.Printf("  -h, --help      %s\n", getMessage("flag_help"))
	fmt.Printf("  -v, --version   %s\n", getMessage("flag_version"))
	fmt.Printf("  -s, --snapshot  %s\n", getMessage("flag_snapshot"))
	fmt.Printf("  --no-snap       %s\n", getMessage("flag_no_snap"))
	fmt.Printf("  --no-flatpak    %s\n", getMessage("flag_no_flatpak"))
	fmt.Printf("  --no-reboot     %s\n", getMessage("flag_no_reboot"))
	fmt.Printf("  --dist-upgrade  %s\n", getMessage("flag_dist_upgrade"))

	fmt.Printf("\n%s\n", getMessage("help_examples"))
	fmt.Printf("  %s              %s\n", os.Args[0], getMessage("help_example_1"))
	fmt.Printf("  %s -s           %s\n", os.Args[0], getMessage("help_example_2"))
	fmt.Printf("  %s --no-snap --no-flatpak  %s\n", os.Args[0], getMessage("help_example_4"))

	fmt.Printf("\n%s\n  NDXDev (NDXDev@gmail.com)\n", getMessage("help_author"))
	fmt.Printf("\n%s\n  MIT\n", getMessage("help_license"))
}

func main() {
	// Detect and load language
	detectedLang := detectLanguage()
	if err := loadLanguage(detectedLang); err != nil {
		log.Printf("Erreur de chargement de la langue %s: %v", detectedLang, err)
		// Fallback to English
		if err := loadLanguage("en"); err != nil {
			log.Fatalf("Impossible de charger la langue par défaut: %v", err)
		}
	}

	// Default configuration
	config := Config{
		CreateSnapshot:    false,
		UpdateSnap:        true,
		UpdateFlatpak:     true,
		CheckRebootNeeded: true,
	}

	var distUpgrade bool = false

	// Definition of flags
	var help, showVersionFlag bool
	flag.BoolVar(&help, "h", false, getMessage("flag_help"))
	flag.BoolVar(&help, "help", false, getMessage("flag_help"))
	flag.BoolVar(&showVersionFlag, "v", false, getMessage("flag_version"))
	flag.BoolVar(&showVersionFlag, "version", false, getMessage("flag_version"))
	flag.BoolVar(&config.CreateSnapshot, "s", false, getMessage("flag_snapshot"))
	flag.BoolVar(&config.CreateSnapshot, "snapshot", false, getMessage("flag_snapshot"))

	var noSnap, noFlatpak, noReboot bool
	flag.BoolVar(&noSnap, "no-snap", false, getMessage("flag_no_snap"))
	flag.BoolVar(&noFlatpak, "no-flatpak", false, getMessage("flag_no_flatpak"))
	flag.BoolVar(&noReboot, "no-reboot", false, getMessage("flag_no_reboot"))

	flag.BoolVar(&distUpgrade, "dist-upgrade", false, getMessage("flag_dist_upgrade"))

	flag.Parse()

	// Help and version management
	if help {
		showHelp()
		os.Exit(0)
	}

	if showVersionFlag {
		showVersion()
		os.Exit(0)
	}

	// Applying negative flags
	if noSnap {
		config.UpdateSnap = false
	}
	if noFlatpak {
		config.UpdateFlatpak = false
	}
	if noReboot {
		config.CheckRebootNeeded = false
	}

	// Header
	printMessage(Green, getMessage("app_title"))
	printMessage(Blue, getMessage("start_time", time.Now().Format("2006-01-02 15:04:05")))
	fmt.Println()

	// Preliminary checks
	if err := checkRoot(); err != nil {
		log.Fatal(err)
	}

	if err := checkInternet(); err != nil {
		log.Fatal(err)
	}

	// Creation of the snapshot if requested
	if config.CreateSnapshot {
		if err := createSnapshot(); err != nil {
			printMessage(Yellow, getMessage("error_snapshot", err))
		}
		fmt.Println()
	}

	// System Update
	if err := updateSystem(distUpgrade); err != nil {
		log.Fatal(getMessage("error_update", err))
	}
	fmt.Println()

	// Updating Snap packages
	if config.UpdateSnap {
		if err := updateSnap(); err != nil {
			printMessage(Yellow, getMessage("error_snap", err))
		}
		fmt.Println()
	}

	// Update Flatpak packages
	if config.UpdateFlatpak {
		if err := updateFlatpak(); err != nil {
			printMessage(Yellow, getMessage("error_flatpak", err))
		}
		fmt.Println()
	}

	// Reboot Check
	if config.CheckRebootNeeded {
		if err := checkReboot(); err != nil {
			printMessage(Yellow, getMessage("error_reboot", err))
		}
	}

	printMessage(Green, getMessage("app_finished"))
	printMessage(Blue, getMessage("end_time", time.Now().Format("2006-01-02 15:04:05")))
}
