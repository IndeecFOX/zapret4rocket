# UI helpers

pause_enter() {
  read -re -p "Enter для продолжения" _
}

submenu_item() {
  echo -e "${green}$1. $2${plain} $3"
}

# Совместимость со старым кодом меню
exit_to_menu() {
  pause_enter
}
