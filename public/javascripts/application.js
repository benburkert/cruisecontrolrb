// Place your application-specific JavaScript functions and classes here
// This file is automatically included by javascript_include_tag :defaults

function toggle_section(section) {
  if (section.className == "section_open")
    section.className = "section_closed"
  else
    section.className = "section_open"
}

function disableBuildNowButton(button) {
  button.className='build_button_disabled';
  button.disabled = true;
}

