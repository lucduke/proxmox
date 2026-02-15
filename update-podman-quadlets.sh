#!/bin/bash

# Script de mise à jour des conteneurs Podman avec Quadlets
# Utilise podman auto-update pour une mise à jour automatique

set -euo pipefail

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
QUADLET_DIR="${QUADLET_DIR:-/etc/containers/systemd}"
LOG_FILE="/tmp/podman-quadlets-update-$(date +%Y%m%d_%H%M%S).log"

# Fonctions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

# Vérifier si le répertoire quadlets existe
check_quadlets_dir() {
    if [ ! -d "$QUADLET_DIR" ]; then
        log_error "Répertoire des quadlets non trouvé: $QUADLET_DIR"
        exit 1
    fi
    log_info "Répertoire des quadlets trouvé: $QUADLET_DIR"
}

# Lister les quadlets disponibles
list_quadlets() {
    log_info "Fichiers quadlets trouvés:"
    ls -1 "$QUADLET_DIR"/*.container 2>/dev/null || log_warning "Aucun fichier .container trouvé"
}

# Recharger les unités systemd
reload_systemd() {
    log_info "Rechargement des unités systemd..."
    systemctl --user daemon-reload
    log_success "Unités systemd rechargées"
}

# Mettre à jour les images avec podman auto-update
update_images() {
    log_info "Démarrage de la mise à jour des images avec podman auto-update..."
    
    if podman auto-update; then
        log_success "Mise à jour des images réussie"
    else
        log_error "La mise à jour des images a échoué"
        return 1
    fi
}

# Nettoyer les images inutilisées
cleanup_images() {
    log_info "Nettoyage des images inutilisées..."
    
    # Utiliser podman image prune pour supprimer les images non utilisées
    if podman image prune -af; then
        log_success "Images inutilisées supprimées"
    else
        log_warning "Erreur lors du nettoyage des images"
        return 1
    fi
}

# Nettoyer les conteneurs arrêtés
cleanup_containers() {
    log_info "Nettoyage des conteneurs arrêtés..."
    
    # Utiliser podman container prune pour supprimer les conteneurs arrêtés
    if podman container prune -f; then
        log_success "Conteneurs arrêtés supprimés"
    else
        log_warning "Erreur lors du nettoyage des conteneurs"
        return 1
    fi
}

# Redémarrer les conteneurs/services
restart_services() {
    log_info "Redémarrage des services..."
    
    # Récupérer les noms des services à partir des fichiers quadlets
    local services=()
    for file in "$QUADLET_DIR"/*.container; do
        if [ -f "$file" ]; then
            local service_name=$(basename "$file" .container)
            services+=("$service_name")
        fi
    done
    
    if [ ${#services[@]} -eq 0 ]; then
        log_warning "Aucun service trouvé"
        return 0
    fi
    
    for service in "${services[@]}"; do
        log_info "Redémarrage du service: $service.service"
        if systemctl restart "$service.service"; then
            log_success "Service $service redémarré"
        else
            log_warning "Impossible de redémarrer $service (peut ne pas être actif)"
        fi
    done
}

# Afficher le statut des conteneurs
show_status() {
    log_info "Statut des conteneurs:"
    podman ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"
}

# Menu principal
main() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  Mise à jour des Podman Quadlets${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    log_info "Démarrage du script de mise à jour"
    log_info "Fichier de log: $LOG_FILE"
    echo ""
    
    # Vérifications
    check_quadlets_dir
    list_quadlets
    echo ""
    
    # Confirmation
    read -p "Voulez-vous procéder à la mise à jour? (y/N) " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Mise à jour annulée par l'utilisateur"
        exit 0
    fi
    
    echo ""
    
    # Processus de mise à jour
    reload_systemd
    echo ""
    
    update_images
    echo ""
    
    restart_services
    echo ""
    
    cleanup_containers
    echo ""
    
    cleanup_images
    echo ""
    
    show_status
    echo ""
    
    log_success "Mise à jour terminée avec succès!"
    log_info "Consultez le fichier de log pour plus de détails: $LOG_FILE"
}

# Gestion des erreurs
trap 'log_error "Script interrompu"; exit 1' SIGINT SIGTERM

# Exécution
main "$@"