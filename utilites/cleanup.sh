#!/bin/bash

###############################################################################
# macOS Disk Cleanup Utility
# A safe, interactive CLI for cleaning up disk space with animations
###############################################################################

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
GRAY='\033[0;90m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# Animation frames
SPINNER_FRAMES=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
PROGRESS_FRAMES=('▁' '▂' '▃' '▄' '▅' '▆' '▇' '█')

# Tracking
TOTAL_FREED=0
OPERATIONS_LOG=~/.cleanup_log_$(date +%Y%m%d_%H%M%S).txt

###############################################################################
# Animation Functions
###############################################################################

# Spinner with message
spinner() {
    local message="$1"
    local duration="${2:-2}"
    local frame=0
    local end=$(echo "$SECONDS + $duration" | bc | cut -d. -f1)
    
    while (( SECONDS < end )); do
        printf "\r${CYAN}${SPINNER_FRAMES[$frame]}${NC} ${message}  "
        frame=$(( (frame + 1) % ${#SPINNER_FRAMES[@]} ))
        sleep 0.1
    done
    printf "\r"
}

# Progress bar animation
progress_bar() {
    local message="$1"
    local duration="${2:-1}"
    local steps=40
    local step_duration=$((duration * 100 / steps))
    
    for ((i = 0; i <= steps; i++)); do
        local percentage=$((i * 100 / steps))
        local filled=$((i * 20 / steps))
        local bar=""
        
        for ((j = 0; j < filled; j++)); do
            bar+="█"
        done
        for ((j = filled; j < 20; j++)); do
            bar+="░"
        done
        
        printf "\r${message} ${CYAN}[${bar}]${NC} ${percentage}%  "
        sleep 0.05
    done
    printf "\r"
}

# Animated text reveal
reveal() {
    local text="$1"
    local color="${2:-$CYAN}"
    for ((i = 0; i < ${#text}; i++)); do
        printf "${color}${text:$i:1}${NC}"
        sleep 0.02
    done
}

# Clear spinner line
clear_spinner() {
    printf "\r\033[K"
}

# Startup animation
startup_animation() {
    clear
    echo ""
    
    # ASCII art title with animation
    local title_lines=(
        "  ╔═══════════════════════════════════════╗"
        "  ║                                       ║"
        "  ║${CYAN}       🧹  CLEANUP UTILITY  🧹${NC}        ║"
        "  ║                                       ║"
        "  ╚═══════════════════════════════════════╝"
    )
    
    # Animate title appearance
    for line in "${title_lines[@]}"; do
        echo -e "$line"
        sleep 0.1
    done
    
    echo ""
    
    # Animated spinner with status message
    spinner "Initializing" 1.5 &
    local spinner_pid=$!
    wait $spinner_pid 2>/dev/null || true
    clear_spinner
    
    echo ""
    echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # Show system info with reveal animation
    printf "${GRAY}System: ${NC}"
    reveal "$(uname -s) $(uname -r | cut -d. -f1-2)" "$CYAN"
    echo ""
    printf "${GRAY}Time:   ${NC}"
    reveal "$(date '+%Y-%m-%d %H:%M:%S')" "$CYAN"
    echo ""
    
    echo ""
    echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    sleep 0.5
}

###############################################################################
# Utility Functions
###############################################################################

log() {
    echo "[$( date +'%Y-%m-%d %H:%M:%S' )] $1" >> "$OPERATIONS_LOG"
}

print_header() {
    echo ""
    echo -e "${BOLD}${CYAN}› $1${NC}"
    echo -e "${GRAY}$(printf '─%.0s' {1..60})${NC}"
}

print_warning() {
    echo -e "${RED}⚠  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✔ $1${NC}"
}

print_info() {
    echo -e "${GRAY}ℹ $1${NC}"
}

get_size() {
    if [ -e "$1" ]; then
        du -sh "$1" 2>/dev/null | awk '{print $1}' || echo "unknown"
    else
        echo "not found"
    fi
}

confirm_action() {
    local prompt="$1"
    local response
    
    while true; do
        read -p "$(echo -e ${BOLD}${CYAN}?${NC} ${prompt} ${GRAY}[yes/no]${NC} ) " response
        case "$response" in
            [yY][eE][sS]|[yY])
                return 0
                ;;
            [nN][oO]|[nN])
                return 1
                ;;
            *)
                echo -e "${GRAY}Please answer 'yes' or 'no'${NC}"
                ;;
        esac
    done
}

show_current_disk_usage() {
    echo -e "${GRAY}$(df -h | grep "/System/Volumes/Data" | awk '{printf "  Used: %s  Available: %s  Usage: %s", $3, $4, $5}')${NC}"
}

perform_cleanup() {
    local path="$1"
    local description="$2"
    local command="$3"
    
    spinner "Removing $description" 1 &
    local spinner_pid=$!
    
    eval "$command" 2>/dev/null || true
    
    wait $spinner_pid 2>/dev/null || true
    clear_spinner
    print_success "$description cleared"
}

cleanup_cache_pip() {
    local path="$HOME/.cache/pip"
    local size=$(get_size "$path")
    
    echo -e "  ${GRAY}pip cache${NC} ${GRAY}$size${NC}"
    
    if [ "$size" != "not found" ] && [ "$size" != "0" ]; then
        if confirm_action "Delete pip cache?"; then
            perform_cleanup "$path" "pip cache" "rm -rf '$path'"
            log "CLEANED: pip cache ($size)"
            return 0
        fi
    fi
    return 1
}

cleanup_cache_all() {
    local path="$HOME/.cache"
    local size=$(get_size "$path")
    
    print_warning "This will clear all caches (Conda, browsers, etc.)"
    echo -e "  ${GRAY}cache size${NC} ${GRAY}$size${NC}"
    
    if confirm_action "Delete all cache?"; then
        spinner "Clearing all caches" 2 &
        local spinner_pid=$!
        
        rm -rf "$path"/* 2>/dev/null || true
        
        wait $spinner_pid 2>/dev/null || true
        clear_spinner
        print_success "Cache cleared"
        log "CLEANED: all cache ($size)"
        return 0
    fi
    return 1
}

cleanup_npm_cache() {
    local size=$(npm cache ls 2>/dev/null | wc -l)
    
    echo -e "  ${GRAY}npm cache${NC} ${GRAY}${size} entries${NC}"
    
    if confirm_action "Clean npm cache?"; then
        perform_cleanup "" "npm cache" "npm cache clean --force 2>/dev/null"
        log "CLEANED: npm cache"
        return 0
    fi
    return 1
}

cleanup_docker_cache() {
    local docker_installed=false
    local docker_running=false
    
    # Check if Docker is installed and running
    if command -v docker &> /dev/null; then
        docker_installed=true
        if docker ps &>/dev/null; then
            docker_running=true
        fi
    fi
    
    echo -e "  ${GRAY}Cleanup options:${NC}"
    if [ "$docker_running" = true ]; then
        echo -e "    ${CYAN}1${NC}  Safe cleanup (stopped containers, dangling images)"
        echo -e "    ${CYAN}2${NC}  Aggressive (unused images, networks, build cache)"
        echo -e "    ${CYAN}3${NC}  Full (also remove unused volumes)"
    fi
    echo -e "    ${CYAN}4${NC}  Remove Docker Desktop files (uninstall cleanup)"
    echo -e "    ${CYAN}0${NC}  Skip"
    echo ""
    
    read -p "$(echo -e ${BOLD}${CYAN}?${NC}) Select Docker cleanup level: " docker_choice
    
    case $docker_choice in
        1)
            if [ "$docker_running" != true ]; then
                print_warning "Docker not running, cannot use safe mode"
                return 1
            fi
            if confirm_action "Run safe Docker cleanup?"; then
                spinner "Cleaning Docker (safe mode)" 2 &
                local spinner_pid=$!
                docker system prune -f 2>/dev/null || true
                wait $spinner_pid 2>/dev/null || true
                clear_spinner
                print_success "Docker cleanup complete (safe mode)"
                log "CLEANED: Docker cache (safe mode)"
                return 0
            fi
            ;;
        2)
            if [ "$docker_running" != true ]; then
                print_warning "Docker not running, cannot use aggressive mode"
                return 1
            fi
            print_warning "This will remove unused images (but keeps tagged ones)"
            if confirm_action "Run aggressive Docker cleanup?"; then
                spinner "Cleaning Docker (aggressive mode)" 2 &
                local spinner_pid=$!
                docker system prune -a -f 2>/dev/null || true
                wait $spinner_pid 2>/dev/null || true
                clear_spinner
                print_success "Docker cleanup complete (aggressive mode)"
                log "CLEANED: Docker cache (aggressive mode)"
                return 0
            fi
            ;;
        3)
            if [ "$docker_running" != true ]; then
                print_warning "Docker not running, cannot use full mode"
                return 1
            fi
            print_warning "This will remove unused volumes - ensure no important data is lost"
            if confirm_action "Run full Docker cleanup (including volumes)?"; then
                spinner "Cleaning Docker (full mode)" 2 &
                local spinner_pid=$!
                docker system prune -a -f --volumes 2>/dev/null || true
                wait $spinner_pid 2>/dev/null || true
                clear_spinner
                print_success "Docker cleanup complete (full mode)"
                log "CLEANED: Docker cache (full mode)"
                return 0
            fi
            ;;
        4)
            print_warning "This will remove ALL Docker data (images, containers, volumes, configs)"
            echo ""
            echo -e "  ${GRAY}Calculating sizes...${NC}"
            
            # Calculate total size
            local total_size=0
            local docker_dirs=(
                "$HOME/Library/Containers/com.docker.docker"
                "$HOME/Library/Application Support/Docker"
                "$HOME/.docker"
                "$HOME/Library/Caches/Docker"
                "$HOME/Library/Logs/Docker"
            )
            
            echo -e "  ${GRAY}Directories to be removed:${NC}"
            for dir in "${docker_dirs[@]}"; do
                if [ -e "$dir" ]; then
                    local dir_size=$(get_size "$dir")
                    echo -e "    ${CYAN}$dir${NC} ${GRAY}($dir_size)${NC}"
                else
                    echo -e "    ${GRAY}$dir${NC} ${GRAY}(not found)${NC}"
                fi
            done
            
            # Check for additional Docker data locations
            echo -e "  ${GRAY}Additional files:${NC}"
            echo -e "    ${GRAY}~/Library/Preferences/com.docker.docker.plist${NC}"
            
            # Keychain entries
            local keychain_count=$(security find-generic-password -s docker 2>/dev/null | wc -l)
            if [ "$keychain_count" -gt 0 ]; then
                echo -e "    ${CYAN}Keychain entries${NC} ${GRAY}(will be removed)${NC}"
            fi
            
            echo ""
            if confirm_action "Proceed with complete Docker removal?"; then
                spinner "Removing all Docker data" 2 &
                local spinner_pid=$!
                
                # Kill any running Docker processes
                killall Docker 2>/dev/null || true
                killall com.docker.osx.hyperkit.linux 2>/dev/null || true
                sleep 0.5
                
                # Remove directories
                for dir in "${docker_dirs[@]}"; do
                    rm -rf "$dir" 2>/dev/null || sudo rm -rf "$dir" 2>/dev/null || true
                done
                
                # Remove preferences
                rm -f "$HOME/Library/Preferences/com.docker.docker.plist" 2>/dev/null || true
                
                # Remove Keychain entries (optional)
                security delete-generic-password -s docker 2>/dev/null || true
                
                wait $spinner_pid 2>/dev/null || true
                clear_spinner
                
                # Verify removal
                echo ""
                echo -e "  ${GRAY}Verification:${NC}"
                local remaining=0
                for dir in "${docker_dirs[@]}"; do
                    if [ -e "$dir" ]; then
                        echo -e "    ${RED}✗${NC} $dir ${GRAY}(still exists)${NC}"
                        ((remaining++))
                    else
                        echo -e "    ${GREEN}✓${NC} $dir ${GRAY}(removed)${NC}"
                    fi
                done
                
                if [ $remaining -eq 0 ]; then
                    print_success "All Docker files removed successfully"
                    log "CLEANED: All Docker data (complete uninstall)"
                    return 0
                else
                    print_warning "Some Docker directories still exist (may need sudo)"
                    log "CLEANED: Docker data removed (some directories may require manual removal)"
                    return 0
                fi
            fi
            ;;
        0)
            print_info "Docker cleanup skipped"
            return 1
            ;;
        *)
            print_info "Invalid choice"
            return 1
            ;;
    esac
    return 1
}

cleanup_container_caches() {
    local path="$HOME/Library/Containers"
    local size=$(get_size "$path")
    
    echo -e "  ${GRAY}Container caches${NC} ${GRAY}$size${NC}"
    print_warning "May require re-login to some apps after clearing"
    
    if confirm_action "Delete container caches?"; then
        spinner "Clearing container caches" 2 &
        local spinner_pid=$!
        
        find "$path" -type d -name "Cache*" -exec rm -rf {} + 2>/dev/null || true
        
        wait $spinner_pid 2>/dev/null || true
        clear_spinner
        print_success "Container caches cleared"
        log "CLEANED: Container caches"
        return 0
    fi
    return 1
}

cleanup_micromamba() {
    echo -e "  ${GRAY}micromamba cache${NC}"
    
    if confirm_action "Clean micromamba cache?"; then
        spinner "Cleaning micromamba cache" 1.5 &
        local spinner_pid=$!
        
        ~/.micromamba/bin/micromamba clean --all -y 2>/dev/null || true
        
        wait $spinner_pid 2>/dev/null || true
        clear_spinner
        print_success "Micromamba cache cleared"
        log "CLEANED: micromamba cache"
        return 0
    fi
    return 1
}

cleanup_browser_caches() {
    print_header "Browser Caches"
    
    # Chrome
    local chrome_path="$HOME/Library/Caches/Google/Chrome"
    local chrome_size=$(get_size "$chrome_path")
    echo -e "  ${GRAY}Chrome${NC} ${GRAY}$chrome_size${NC}"
    if confirm_action "Delete Chrome cache?"; then
        perform_cleanup "$chrome_path" "Chrome cache" "rm -rf '$chrome_path'"
        log "CLEANED: Chrome cache"
    fi
    echo ""
    
    # Firefox
    local firefox_path="$HOME/Library/Application Support/Firefox"
    local firefox_size=$(get_size "$firefox_path")
    echo -e "  ${GRAY}Firefox${NC} ${GRAY}$firefox_size${NC}"
    if confirm_action "Delete Firefox cache?"; then
        perform_cleanup "$firefox_path" "Firefox cache" "rm -rf '$firefox_path'"
        log "CLEANED: Firefox cache"
    fi
    echo ""
    
    # Opera
    local opera_path="$HOME/Library/Application Support/com.operasoftware.OperaGX"
    local opera_size=$(get_size "$opera_path")
    echo -e "  ${GRAY}Opera${NC} ${GRAY}$opera_size${NC}"
    if confirm_action "Delete Opera cache?"; then
        spinner "Clearing Opera cache" 1 &
        local spinner_pid=$!
        
        find "$opera_path" -type d -name "Cache*" -exec rm -rf {} + 2>/dev/null || true
        
        wait $spinner_pid 2>/dev/null || true
        clear_spinner
        print_success "Opera cache cleared"
        log "CLEANED: Opera cache"
    fi
}

cleanup_unused_apps() {
    print_header "Unused Application Data"
    
    local apps=(
        "WebEx Folder:417M"
        "Code - Insiders:519M"
        "BraveSoftware:498M"
        "Zoom:123M"
    )
    
    for app_info in "${apps[@]}"; do
        IFS=':' read -r app_name app_size <<< "$app_info"
        local app_path="$HOME/Library/Application Support/$app_name"
        
        if [ -e "$app_path" ]; then
            echo -e "  ${GRAY}$app_name${NC} ${GRAY}~$app_size${NC}"
            if confirm_action "Delete $app_name?"; then
                perform_cleanup "$app_path" "$app_name" "rm -rf '$app_path'"
                log "CLEANED: $app_name"
            fi
            echo ""
        fi
    done
}

cleanup_old_logs() {
    print_header "Old Logs & Temporary Files"
    
    # Old logs
    local logs_path="$HOME/Library/Logs"
    local logs_size=$(get_size "$logs_path")
    echo -e "  ${GRAY}Logs directory${NC} ${GRAY}$logs_size${NC}"
    if confirm_action "Delete old logs (>30 days)?"; then
        spinner "Scanning and removing old logs" 2 &
        local spinner_pid=$!
        
        find "$logs_path" -type f -mtime +30 -delete 2>/dev/null || true
        
        wait $spinner_pid 2>/dev/null || true
        clear_spinner
        print_success "Old logs cleared"
        log "CLEANED: Old logs"
    fi
    echo ""
}

cleanup_trash() {
    print_header "Empty Trash"
    
    local trash_path="$HOME/.Trash"
    if [ -e "$trash_path" ]; then
        local trash_size=$(get_size "$trash_path")
        echo -e "  ${GRAY}Current trash size:${NC} ${CYAN}${BOLD}$trash_size${NC}${BOLD}${NC}"
        echo ""
        
        if confirm_action "Empty Trash?"; then
            spinner "Emptying trash" 1.5 &
            local spinner_pid=$!
            
            rm -rf "$trash_path"/* 2>/dev/null || true
            
            wait $spinner_pid 2>/dev/null || true
            clear_spinner
            print_success "Trash emptied"
            log "CLEANED: Trash ($trash_size)"
            return 0
        fi
    else
        print_info "Trash is already empty"
        return 1
    fi
    return 1
}

cleanup_development() {
    print_header "Development Caches (Advanced)"
    
    local paths=(
        "clangd:$HOME/Library/Caches/clangd"
        "pylance:$HOME/Library/Caches/pylance"
        "Xcode derived data:$HOME/Library/Developer/Xcode/DerivedData"
    )
    
    for item in "${paths[@]}"; do
        IFS=':' read -r name path <<< "$item"
        if [ -e "$path" ]; then
            local size=$(get_size "$path")
            echo -e "  ${GRAY}$name${NC} ${GRAY}$size${NC}"
            if confirm_action "Delete $name?"; then
                perform_cleanup "$path" "$name" "rm -rf '$path'"
                log "CLEANED: $name"
            fi
            echo ""
        fi
    done
}

show_menu() {
    clear
    echo ""
    echo -e "${BOLD}${CYAN}cleanup${NC} ${GRAY}v1.2${NC}"
    echo -e "${GRAY}macOS disk cleanup utility${NC}"
    echo ""
    print_header "Disk Status"
    show_current_disk_usage
    echo ""
    echo -e "${BOLD}Quick Actions${NC}"
    echo -e "  ${CYAN}1${NC}  Quick cleanup (npm, pip caches)"
    echo -e "  ${CYAN}2${NC}  Aggressive cleanup (all caches)"
    echo -e "  ${CYAN}3${NC}  Browser caches"
    echo -e "  ${CYAN}4${NC}  Docker cache"
    echo -e "  ${CYAN}5${NC}  Unused applications"
    echo -e "  ${CYAN}6${NC}  Old logs"
    echo -e "  ${CYAN}7${NC}  Empty trash"
    echo ""
    echo -e "${BOLD}Advanced${NC}"
    echo -e "  ${CYAN}8${NC}  Development caches"
    echo -e "  ${CYAN}9${NC}  Container app caches"
    echo -e "  ${CYAN}10${NC} micromamba cache"
    echo -e "  ${CYAN}11${NC} Full cleanup (all of above)"
    echo ""
    echo -e "  ${CYAN}0${NC}  Exit"
    echo ""
}

run_full_cleanup() {
    print_warning "Full cleanup will run all cleanup operations"
    echo -e "${GRAY}You'll be prompted for confirmation for each operation${NC}"
    echo ""
    
    if confirm_action "Proceed with full cleanup?"; then
        spinner "Starting full cleanup sequence" 1 &
        local spinner_pid=$!
        wait $spinner_pid 2>/dev/null || true
        clear_spinner
        
        cleanup_cache_pip
        cleanup_cache_all
        cleanup_npm_cache
        cleanup_browser_caches
        cleanup_docker_cache
        cleanup_container_caches
        cleanup_micromamba
        cleanup_unused_apps
        cleanup_old_logs
        cleanup_development
    fi
}

show_summary() {
    echo ""
    print_header "Cleanup Complete"
    
    spinner "Updating disk status" 1 &
    local spinner_pid=$!
    wait $spinner_pid 2>/dev/null || true
    clear_spinner
    
    show_current_disk_usage
    echo ""
    print_success "Log saved to: $OPERATIONS_LOG"
    echo ""
}

###############################################################################
# Main Script
###############################################################################

main() {
     # Check if running on macOS
     if [[ "$OSTYPE" != "darwin"* ]]; then
         print_warning "This script is designed for macOS only"
         exit 1
     fi
     
     # Show startup animation on first run
     startup_animation
     
     # Initialize log
     log "=== Cleanup session started ==="
     log "Initial disk usage:"
     log "$(df -h | grep /System/Volumes/Data)"
     
     while true; do
        show_menu
        read -p "$(echo -e ${BOLD}${CYAN}?${NC}) Select action: " choice
        
        case $choice in
             1)
                 print_header "Quick Cleanup"
                 cleanup_cache_pip
                 cleanup_npm_cache
                 show_summary
                 ;;
             2)
                 print_header "Aggressive Cleanup"
                 cleanup_cache_all
                 show_summary
                 ;;
             3)
                 cleanup_browser_caches
                 show_summary
                 ;;
             4)
                 cleanup_docker_cache
                 show_summary
                 ;;
             5)
                 cleanup_unused_apps
                 show_summary
                 ;;
             6)
                 cleanup_old_logs
                 show_summary
                 ;;
             7)
                 cleanup_trash
                 show_summary
                 ;;
             8)
                 cleanup_development
                 show_summary
                 ;;
             9)
                 cleanup_container_caches
                 show_summary
                 ;;
             10)
                 cleanup_micromamba
                 show_summary
                 ;;
             11)
                 run_full_cleanup
                 show_summary
                 ;;
             0)
                 show_summary
                 exit 0
                 ;;
             *)
                 print_info "Invalid choice. Please try again."
                 ;;
         esac
        
        echo ""
    done
}

# Run main function
main "$@"
