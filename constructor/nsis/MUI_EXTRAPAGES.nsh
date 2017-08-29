# License:
#  This header file is provided 'as-is', without any express or implied
#  warranty. In no event will the author be held liable for any damages arising
#  from the use of this header file.
#
#  Permission is granted to anyone to use this header file for any purpose,
#  including commercial applications, and to alter it and redistribute it
#  freely, subject to the following restrictions:
#
#   1. The origin of this header file must not be misrepresented; you must not
#      claim that you wrote the original header file. If you use this header
#      file a product, an acknowledgment in the product documentation would be
#      appreciated but is not required.
#   2. Altered versions must be plainly marked as such, and must not be
#      misrepresented as being the original header file.
#   3. This notice may not be removed or altered from any distribution.
#
# Source: http://nsis.sourceforge.net/Readme_Page_Based_on_MUI_License_Page

#   MUI_EXTRAPAGES.nsh
#   By Red Wine Jan 2007

!verbose push
!verbose 3

!ifndef _MUI_EXTRAPAGES_NSH
!define _MUI_EXTRAPAGES_NSH

!ifmacrondef MUI_EXTRAPAGE_README & MUI_PAGE_README & MUI_UNPAGE_README & ReadmeLangStrings

!macro MUI_EXTRAPAGE_README UN ReadmeFile
!verbose push
!verbose 3
   !define MUI_PAGE_HEADER_TEXT "$(${UN}ReadmeHeader)"
   !define MUI_PAGE_HEADER_SUBTEXT "$(${UN}ReadmeSubHeader)"
   !define MUI_LICENSEPAGE_TEXT_TOP "$(${UN}ReadmeTextTop)"
   !define MUI_LICENSEPAGE_TEXT_BOTTOM "$(${UN}ReadmeTextBottom)"
   !define MUI_LICENSEPAGE_BUTTON "$(^NextBtn)"
   !insertmacro MUI_${UN}PAGE_LICENSE "${ReadmeFile}"
!verbose pop
!macroend

!define ReadmeRun "!insertmacro MUI_EXTRAPAGE_README"


!macro MUI_PAGE_README ReadmeFile
!verbose push
!verbose 3
    ${ReadmeRun} "" "${ReadmeFile}"
!verbose pop
!macroend


!macro MUI_UNPAGE_README ReadmeFile
!verbose push
!verbose 3
    ${ReadmeRun} "UN" "${ReadmeFile}"
!verbose pop
!macroend


!macro ReadmeLangStrings UN MUI_LANG ReadmeHeader ReadmeSubHeader ReadmeTextTop ReadmeTextBottom
!verbose push
!verbose 3
    LangString ${UN}ReadmeHeader     ${MUI_LANG} "${ReadmeHeader}"
    LangString ${UN}ReadmeSubHeader  ${MUI_LANG} "${ReadmeSubHeader}"
    LangString ${UN}ReadmeTextTop    ${MUI_LANG} "${ReadmeTextTop}"
    LangString ${UN}ReadmeTextBottom ${MUI_LANG} "${ReadmeTextBottom}"
!verbose pop
!macroend

!define ReadmeLanguage `!insertmacro ReadmeLangStrings ""`

!define Un.ReadmeLanguage `!insertmacro ReadmeLangStrings "UN"`

!endif
!endif

!verbose pop
