# UI helpers

pause_enter() {
  read -r -p "Enter для продолжения" _
}

submenu_item() {
  echo -e "${green}$1.${yellow} $2${plain}"
}

# Совместимость со старым кодом меню
exit_to_menu() {
  pause_enter
}
