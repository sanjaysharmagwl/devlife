#!/bin/bash

###############################################################################
# macOS Disk Cleanup Utility
# A safe, interactive CLI for cleaning up disk space
###############################################################################

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Tracking
TOTAL_FREED=0
OPERATIONS_LOG=~/.cleanup_log_$(date +%Y%m%d_%H%M%S).txt

###############################################################################
# Utility Functions
###############################################################################

log() {
    echo "[$( date +'%Y-%m-%d %H:%M:%S' )] $1" >> "$OPERATIONS_LOG"
}

print_header() {
    echo ""
    echo -e "${BLUE}=======================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}=======================================${NC}"
}

print_warning() {
    echo -e "${RED}⚠️  WARNING: $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
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
        read -p "$(echo -e ${YELLOW}$prompt${NC}) (yes/no): " response
        case "$response" in
            [yY][eE][sS]|[yY])
                return 0
                ;;
            [nN][oO]|[nN])
                return 1
                ;;
            *)
                echo "Please answer 'yes' or 'no'"
                ;;
        esac
    done
}

show_current_disk_usage() {
    print_header "Current Disk Usage"
    df -h | grep "/System/Volumes/Data" | awk '{printf "Used: %s | Available: %s | Usage: %s\n", $3, $4, $5}'
}

cleanup_cache_pip() {
    local path="$HOME/.cache/pip"
    local size=$(get_size "$path")
    
    print_info "Pip cache: $size"
    
    if [ "$size" != "not found" ] && [ "$size" != "0" ]; then
        if confirm_action "Delete pip cache ($size)?"; then
            rm -rf "$path" 2>/dev/null || true
            print_success "Pip cache cleared"
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
    print_info "Cache size: $size"
    
    if confirm_action "Delete all cache ($size)?"; then
        rm -rf "$path"/* 2>/dev/null || true
        print_success "Cache cleared"
        log "CLEANED: all cache ($size)"
        return 0
    fi
    return 1
}

cleanup_npm_cache() {
    local size=$(npm cache ls 2>/dev/null | wc -l)
    
    print_info "npm cache (estimated)"
    
    if confirm_action "Clean npm cache?"; then
        npm cache clean --force 2>/dev/null || true
        print_success "npm cache cleared"
        log "CLEANED: npm cache"
        return 0
    fi
    return 1
}

cleanup_docker_cache() {
    local path="$HOME/Library/Containers/com.docker.docker/Data/vms/0"
    local size=$(get_size "$path")
    
    print_warning "Deleting Docker VM cache - Docker will rebuild images on demand"
    print_info "Docker cache size: $size"
    
    if confirm_action "Delete Docker cache ($size)?"; then
        rm -rf "$path" 2>/dev/null || true
        print_success "Docker cache cleared"
        log "CLEANED: Docker cache ($size)"
        return 0
    fi
    return 1
}

cleanup_container_caches() {
    local path="$HOME/Library/Containers"
    local size=$(get_size "$path")
    
    print_warning "Clearing container caches - may require re-login to apps"
    print_info "Container caches size: $size"
    
    if confirm_action "Delete container caches ($size)?"; then
        find "$path" -type d -name "Cache*" -exec rm -rf {} + 2>/dev/null || true
        print_success "Container caches cleared"
        log "CLEANED: Container caches"
        return 0
    fi
    return 1
}

cleanup_micromamba() {
    print_info "Running micromamba clean..."
    
    if confirm_action "Clean micromamba cache?"; then
        ~/.micromamba/bin/micromamba clean --all -y 2>/dev/null || true
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
    print_info "Chrome cache: $chrome_size"
    if confirm_action "Delete Chrome cache ($chrome_size)?"; then
        rm -rf "$chrome_path" 2>/dev/null || true
        print_success "Chrome cache cleared"
        log "CLEANED: Chrome cache"
    fi
    
    # Firefox
    local firefox_path="$HOME/Library/Application Support/Firefox"
    local firefox_size=$(get_size "$firefox_path")
    print_info "Firefox cache: $firefox_size"
    if confirm_action "Delete Firefox cache ($firefox_size)?"; then
        rm -rf "$firefox_path" 2>/dev/null || true
        print_success "Firefox cache cleared"
        log "CLEANED: Firefox cache"
    fi
    
    # Opera
    local opera_path="$HOME/Library/Application Support/com.operasoftware.OperaGX"
    local opera_size=$(get_size "$opera_path")
    print_info "Opera cache: $opera_size"
    if confirm_action "Delete Opera cache ($opera_size)?"; then
        find "$opera_path" -type d -name "Cache*" -exec rm -rf {} + 2>/dev/null || true
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
            print_info "$app_name (~$app_size)"
            if confirm_action "Delete $app_name?"; then
                rm -rf "$app_path" 2>/dev/null || true
                print_success "$app_name cleared"
                log "CLEANED: $app_name"
            fi
        fi
    done
}

cleanup_old_logs() {
    print_header "Old Logs & Temporary Files"
    
    # Old logs
    local logs_path="$HOME/Library/Logs"
    local logs_size=$(get_size "$logs_path")
    print_info "Logs directory: $logs_size"
    if confirm_action "Delete old logs (>30 days)?"; then
        find "$logs_path" -type f -mtime +30 -delete 2>/dev/null || true
        print_success "Old logs cleared"
        log "CLEANED: Old logs"
    fi
    
    # Trash
    local trash_path="$HOME/.Trash"
    if [ -e "$trash_path" ]; then
        local trash_size=$(get_size "$trash_path")
        print_info "Trash: $trash_size"
        if confirm_action "Empty Trash ($trash_size)?"; then
            rm -rf "$trash_path"/* 2>/dev/null || true
            print_success "Trash emptied"
            log "CLEANED: Trash"
        fi
    fi
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
            print_info "$name: $size"
            if confirm_action "Delete $name?"; then
                rm -rf "$path" 2>/dev/null || true
                print_success "$name cleared"
                log "CLEANED: $name"
            fi
        fi
    done
}

show_menu() {
    print_header "macOS Cleanup Utility"
    show_current_disk_usage
    echo ""
    echo "Choose cleanup operations:"
    echo "1) Quick cleanup (npm, pip caches)"
    echo "2) Aggressive cleanup (all caches)"
    echo "3) Browser caches"
    echo "4) Docker cache"
    echo "5) Unused applications"
    echo "6) Old logs & trash"
    echo "7) Development caches"
    echo "8) Container app caches"
    echo "9) micromamba cache"
    echo "10) Full cleanup (all of above)"
    echo "0) Exit"
    echo ""
}

run_full_cleanup() {
    print_warning "FULL CLEANUP will run all cleanup operations"
    print_warning "You'll be prompted for confirmation for EACH operation"
    
    if confirm_action "Proceed with full cleanup?"; then
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
    print_header "Cleanup Complete"
    show_current_disk_usage
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
    
    # Initialize log
    log "=== Cleanup session started ==="
    log "Initial disk usage:"
    log "$(df -h | grep /System/Volumes/Data)"
    
    while true; do
        show_menu
        read -p "Enter choice (0-10): " choice
        
        case $choice in
            1)
                print_header "Quick Cleanup"
                cleanup_cache_pip
                cleanup_npm_cache
                ;;
            2)
                print_header "Aggressive Cleanup"
                cleanup_cache_all
                ;;
            3)
                cleanup_browser_caches
                ;;
            4)
                cleanup_docker_cache
                ;;
            5)
                cleanup_unused_apps
                ;;
            6)
                cleanup_old_logs
                ;;
            7)
                cleanup_development
                ;;
            8)
                cleanup_container_caches
                ;;
            9)
                cleanup_micromamba
                ;;
            10)
                run_full_cleanup
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
