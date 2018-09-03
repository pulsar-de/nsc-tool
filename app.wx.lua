--[[

    NSC Tool

        Author:       Benjamin Kupka
        License:      GNU GPLv3
        Environment:  wxLua-2.8.12.3-Lua-5.1.5-MSW-Unicode

        Beschreibung: Das Tool erinnert akustisch an die notwendigen Telefonate an die zuständige Serviceleitstelle

        Dieses Projekt ist unter GPLv3 lizensiert, für mehr Informationen: 'docs/LICENSE'.
        Die Versionshistory (Changelog): 'docs/CHANGELOG'.

]]


-------------------------------------------------------------------------------------------------------------------------------------
--// IMPORTS //----------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------

--// Grundlegende Pfad-Konstanten
dofile( "data/cfg/const.lua" )

--// Modul Pfad
package.path = ";./" .. LUALIB_PATH .. "?.lua" ..
               ";./" .. CORE_PATH .. "?.lua"

--// Modul Pfad
package.cpath = ";./" .. CLIB_PATH .. "?.dll"

--// Module importieren
local wx   = require( "wx" )
local util = require( "util" )

-------------------------------------------------------------------------------------------------------------------------------------
--// TABLE LOOKUPS //----------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------

local util_loadtable = util.loadtable
local util_savetable = util.savetable

-------------------------------------------------------------------------------------------------------------------------------------
--// BASIC CONST //------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------

--// Programm Definitionen
local app_name         = "NSC Tool"
local app_version      = "v0.3"
local app_copyright    = "Copyright (C) 2018 by Benjamin Kupka"
local app_license      = "GNU General Public License Version 3"
local app_env          = "Environment: " .. wxlua.wxLUA_VERSION_STRING
local app_build        = "Built with: "..wx.wxVERSION_STRING

local app_width        = 405
local app_height       = 470

local notebook_width   = 399
local notebook_height  = 391

local timer_i          = 1000 -- Timer Intervall (60 Sekunden)
local timer_m          = false -- Timer Modus; false = endless timer / true = one time (oneShot)

--// Datenbanken
local file_cfg         = CFG_PATH .. "cfg.tbl"
local file_user        = DB_PATH ..  "user.tbl"
local file_book        = DB_PATH ..  "book.tbl"
local file_timer       = DB_PATH ..  "timer.tbl"

--// Dateien
local file_png_gpl     = RES_PATH .. "GPLv3_160x80.png"
local file_png_osi     = RES_PATH .. "osi_75x100.png"
local file_png_app_16  = RES_PATH .. "appicon_16x16.png"
local file_png_app_32  = RES_PATH .. "appicon_32x32.png"
local file_png_user    = RES_PATH .. "user.png"
local file_png_phone   = RES_PATH .. "phonebook.png"
local file_png_clock   = RES_PATH .. "clock.png"
local file_png_timer   = RES_PATH .. "timer.png"

local alarm_tbl = {

    [ 1 ] = { RES_PATH .. "AlarmClock.mp3", "AlarmClock" },
    [ 2 ] = { RES_PATH .. "AnalogWatch.mp3", "AnalogWatch" },
    [ 3 ] = { RES_PATH .. "HouseFireAlarm.mp3", "HouseFireAlarm" },
    [ 4 ] = { RES_PATH .. "MetalMetronome.mp3", "MetalMetronome" },
    [ 5 ] = { RES_PATH .. "MissileAlert.mp3", "MissileAlert" },
    [ 6 ] = { RES_PATH .. "OldBell.mp3", "OldBell" },
    [ 7 ] = { RES_PATH .. "OldFashionDoor.mp3", "OldFashionDoor" },
    [ 8 ] = { RES_PATH .. "RoosterCrow.mp3", "RoosterCrow" },
    [ 9 ] = { RES_PATH .. "TornadoSiren.mp3", "TornadoSiren" },
}

--// Datenbanken importieren
local cfg_tbl          = util_loadtable( file_cfg )
local user_tbl         = util_loadtable( file_user )
local book_tbl         = util_loadtable( file_book )
local timer_tbl        = util_loadtable( file_timer )

--// Fonts
local default_font     = wx.wxFont( 8,  wx.wxMODERN, wx.wxNORMAL, wx.wxNORMAL, false, "Verdana" )
local about_normal_1   = wx.wxFont( 9,  wx.wxMODERN, wx.wxNORMAL, wx.wxNORMAL, false, "Verdana" )
local about_normal_2   = wx.wxFont( 10, wx.wxMODERN, wx.wxNORMAL, wx.wxNORMAL, false, "Verdana" )
local about_bold       = wx.wxFont( 10, wx.wxMODERN, wx.wxNORMAL, wx.wxFONTWEIGHT_BOLD, false, "Verdana" )
local timer_bold       = wx.wxFont( 14, wx.wxMODERN, wx.wxNORMAL, wx.wxFONTWEIGHT_BOLD, false, "Verdana" )
local timer_bold_2     = wx.wxFont( 18, wx.wxMODERN, wx.wxNORMAL, wx.wxFONTWEIGHT_BOLD, false, "Verdana" )
local timer_bold_3     = wx.wxFont( 22, wx.wxMODERN, wx.wxNORMAL, wx.wxFONTWEIGHT_BOLD, false, "Verdana" )
local timer_list       = wx.wxFont( 10, wx.wxMODERN, wx.wxNORMAL, wx.wxFONTWEIGHT_BOLD, false, "Verdana" )
local timer_status     = wx.wxFont( 13,  wx.wxMODERN, wx.wxNORMAL, wx.wxFONTWEIGHT_BOLD, false, "Verdana" )
local timer_btn        = wx.wxFont( 18, wx.wxMODERN, wx.wxNORMAL, wx.wxNORMAL, false, "Verdana" )
local alarm_btn        = wx.wxFont( 18, wx.wxMODERN, wx.wxNORMAL, wx.wxFONTWEIGHT_BOLD, false, "Verdana" )

--// Control deklarationen
local control, di, result
local user_choice
local status_textctrl
local timer_start_button
local timer_stop_button
local media_control
local set_timer
local get_current_time_infos
local user_listbox
local time_listbox
local alarmtime_done  = ""


-------------------------------------------------------------------------------------------------------------------------------------
--// IDS //--------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------

--// ID Generator
local id_counter = wx.wxID_HIGHEST + 1
local new_id = function() id_counter = id_counter + 1; return id_counter end

--// IDs
ID_mb_settings = new_id()
ID_mb_tutorial = new_id()

-------------------------------------------------------------------------------------------------------------------------------------
--// MENUBAR //----------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------

local bmp_settings_16x16 = wx.wxArtProvider.GetBitmap( wx.wxART_LIST_VIEW,   wx.wxART_TOOLBAR )
local bmp_exit_16x16     = wx.wxArtProvider.GetBitmap( wx.wxART_QUIT,        wx.wxART_TOOLBAR )
local bmp_about_16x16    = wx.wxArtProvider.GetBitmap( wx.wxART_INFORMATION, wx.wxART_TOOLBAR )
local bmp_tutorial_16x16 = wx.wxArtProvider.GetBitmap( wx.wxART_INFORMATION, wx.wxART_TOOLBAR )

local menu_item = function( menu, id, name, status, bmp )
    local mi = wx.wxMenuItem( menu, id, name, status )
    mi:SetBitmap( bmp )
    bmp:delete()
    return mi
end

local main_menu = wx.wxMenu()
main_menu:Append( menu_item( main_menu, ID_mb_settings, "Einstellungen" .. "\tF3", "Einstellungen öffnen", bmp_settings_16x16 ) )
main_menu:Append( menu_item( main_menu, wx.wxID_EXIT,  "Beenden" .. "\tF4", "Programm beenden", bmp_exit_16x16 ) )

local help_menu = wx.wxMenu()
help_menu:Append( menu_item( help_menu, ID_mb_tutorial, "Anleitung" .. "\tF1", "Bedienungsanleitung für das" .. " " .. app_name, bmp_tutorial_16x16 ) )
help_menu:Append( menu_item( help_menu, wx.wxID_ABOUT, "Über" .. "\tF2", "Informationen über das" .. " " .. app_name, bmp_about_16x16 ) )

local menu_bar = wx.wxMenuBar()
menu_bar:Append( main_menu, "Menü" )
menu_bar:Append( help_menu, "Hilfe" )

-------------------------------------------------------------------------------------------------------------------------------------
--// Frame & Panel //----------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------

--// App Icons (Titelbar & Taskbar)
local app_icons = wx.wxIconBundle()
app_icons:AddIcon( wx.wxIcon( file_png_app_16, wx.wxBITMAP_TYPE_PNG, 16, 16 ) )
app_icons:AddIcon( wx.wxIcon( file_png_app_32, wx.wxBITMAP_TYPE_PNG, 32, 32 ) )

--// Hauptframe
local frame = wx.wxFrame( wx.NULL, wx.wxID_ANY, app_name .. " " .. app_version, wx.wxPoint( 0, 0 ), wx.wxSize( app_width, app_height ), wx.wxMINIMIZE_BOX + wx.wxSYSTEM_MENU + wx.wxCAPTION + wx.wxCLOSE_BOX + wx.wxCLIP_CHILDREN )
frame:Centre( wx.wxBOTH )
frame:SetMenuBar( menu_bar )
frame:SetIcons( app_icons )
frame:CreateStatusBar( 2 )
frame:SetStatusWidths( { ( app_width / 100*80 ), ( app_width / 100*20 ) } )
frame:SetStatusText( app_name .. " bereit.", 0 )
frame:SetStatusText( "Timer: AUS", 1 )

--// Hauptpanel für Frame
local panel = wx.wxPanel( frame, wx.wxID_ANY, wx.wxPoint( 0, 0 ), wx.wxSize( app_width, app_height ) )

--// Loading Media
local mediaCtrl = wx.wxMediaCtrl( frame, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxSize( 0, 0 ) )

-------------------------------------------------------------------------------------------------------------------------------------
--// Notebook //---------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------

local notebook_image_list = wx.wxImageList( 16, 16 )

--// Icon Tab 1 - Profile
local bmp_user_16x16 = wx.wxBitmap():ConvertToImage(); bmp_user_16x16:LoadFile( file_png_user )
local tab_1_img = notebook_image_list:Add( wx.wxBitmap( bmp_user_16x16 ) )

--// Icon Tab 2 - Telefonbuch
local bmp_phone_16x16 = wx.wxBitmap():ConvertToImage(); bmp_phone_16x16:LoadFile( file_png_phone )
local tab_2_img = notebook_image_list:Add( wx.wxBitmap( bmp_phone_16x16 ) )

--// Icon Tab 3 - Uhrzeiten
local bmp_clock_16x16 = wx.wxBitmap():ConvertToImage(); bmp_clock_16x16:LoadFile( file_png_clock )
local tab_3_img = notebook_image_list:Add( wx.wxBitmap( bmp_clock_16x16 ) )

--// Icon Tab 3 - Timer
local bmp_timer_16x16 = wx.wxBitmap():ConvertToImage(); bmp_timer_16x16:LoadFile( file_png_timer )
local tab_4_img = notebook_image_list:Add( wx.wxBitmap( bmp_timer_16x16 ) )

--// Notebook
local notebook = wx.wxNotebook( panel, wx.wxID_ANY, wx.wxPoint( 0, 10 ), wx.wxSize( notebook_width, notebook_height ) )
notebook:SetFont( default_font )
notebook:SetBackgroundColour( wx.wxColour( 225, 225, 225 ) )
notebook:SetImageList( notebook_image_list )

local tab_1 = wx.wxPanel( notebook, wx.wxID_ANY )
notebook:AddPage( tab_1, "1. Profile" )
notebook:SetPageImage( 0, tab_1_img )

local tab_2 = wx.wxPanel( notebook, wx.wxID_ANY )
notebook:AddPage( tab_2, "2. Telefonbuch" )
notebook:SetPageImage( 1, tab_2_img )

local tab_3 = wx.wxPanel( notebook, wx.wxID_ANY )
notebook:AddPage( tab_3, "3. Uhrzeiten" )
notebook:SetPageImage( 2, tab_3_img )

local tab_4 = wx.wxPanel( notebook, wx.wxID_ANY )
notebook:AddPage( tab_4, "4. Timer" )
notebook:SetPageImage( 3, tab_4_img )

-------------------------------------------------------------------------------------------------------------------------------------
--// Timer //------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------

--// Timer 1
timer = nil
timer = wx.wxTimer( panel )

get_current_time_infos = function( t )
    local user_name = user_choice:GetStringSelection()
    for names, v in pairs( timer_tbl ) do
        if names == user_name then
            for tTime, tbl in pairs( v ) do
                if ( tTime == t ) and ( alarmtime_done ~= t ) then
                    alarmtime_done = t
                    for b_name, b_number in pairs( tbl ) do
                        return b_name, b_number
                    end
                end
            end
        end
    end
    return false
end

set_timer = function( mode, dialog )
    local choice = tonumber( user_choice:GetCurrentSelection() )
    if mode then
        if not timer:IsRunning() then
            if choice == -1 then
                di = wx.wxMessageDialog( frame, "Kein Profil in Tab 3 (Uhrzeiten) ausgewählt.", "Hinweis", wx.wxOK )
                di:ShowModal(); di:Destroy()
            else
                timer:Start( timer_i, timer_m )
                timer_start_button:Disable()
                timer_stop_button:Enable( true )
                status_textctrl:SetForegroundColour( wx.wxColour( 80, 240, 114 ) )
                status_textctrl:SetValue( ">     A K T I V I E R T     <" )
                frame:SetStatusText( "Timer: AN", 1 )
                if dialog then
                    di = wx.wxMessageDialog( frame, "Der Timer wurde gestartet.", "Hinweis", wx.wxOK )
                    di:ShowModal(); di:Destroy()
                end
            end
        end
    else
        if timer:IsRunning() then
            timer:Stop()
            timer_start_button:Enable( true )
            timer_stop_button:Disable()
            status_textctrl:SetForegroundColour( wx.wxColour( 255, 0, 0 ) )
            status_textctrl:SetValue( ">  D E A K T I V I E R T  <" )
            frame:SetStatusText( "Timer: AUS", 1 )
            if dialog then
                di = wx.wxMessageDialog( frame, "Der Timer wurde gestoppt.", "Hinweis", wx.wxOK )
                di:ShowModal(); di:Destroy()
            end
        end
    end
end

local show_alert_window = function( time, book_name, book_number )
    --// Dialog Fenster
    local di_tim = wx.wxDialog(
        panel,
        wx.wxID_ANY,
        app_name .. " " .. app_version .. "   Achtung",
        wx.wxDefaultPosition,
        wx.wxSize( 600, 470 ),
        wx.wxSTAY_ON_TOP + wx.wxDEFAULT_DIALOG_STYLE - wx.wxCLOSE_BOX - wx.wxMAXIMIZE_BOX - wx.wxMINIMIZE_BOX
    )
    di_tim:SetMinSize( wx.wxSize( 600, 450 ) )
    di_tim:SetMaxSize( wx.wxSize( 600, 450 ) )
    di_tim:SetBackgroundColour( wx.wxColour( 255, 255, 0 ) )

    --// App Logo
    local app_logo = wx.wxBitmap():ConvertToImage()
    app_logo:LoadFile( file_png_app_32 )

    control = wx.wxStaticBitmap( di_tim, wx.wxID_ANY, wx.wxBitmap( app_logo ), wx.wxPoint( 0, 20 ), wx.wxSize( app_logo:GetWidth(), app_logo:GetHeight() ) )
    control:Centre( wx.wxHORIZONTAL )
    app_logo:Destroy()

    --// App Name / Version
    control = wx.wxStaticText( di_tim, wx.wxID_ANY, app_name .. " " .. app_version, wx.wxPoint( 0, 65 ) )
    control:SetFont( about_bold )
    control:Centre( wx.wxHORIZONTAL )

    --// Horizontale Linie
    control = wx.wxStaticLine( di_tim, wx.wxID_ANY, wx.wxPoint( 0, 105 ), wx.wxSize( 250, 2 ) )
    control:Centre( wx.wxHORIZONTAL )

    --// Dialog Text
    control = wx.wxStaticText( di_tim, wx.wxID_ANY, "Es ist " .. time .. " Uhr", wx.wxPoint( 0, 125 ) )
    control:SetFont( timer_bold )
    control:Centre( wx.wxHORIZONTAL )

    --// Horizontale Linie
    control = wx.wxStaticLine( di_tim, wx.wxID_ANY, wx.wxPoint( 0, 170 ), wx.wxSize( 400, 2 ) )
    control:Centre( wx.wxHORIZONTAL )

    --// Dialog Text
    control = wx.wxStaticText( di_tim, wx.wxID_ANY, book_name, wx.wxPoint( 0, 193 ) )
    control:SetFont( timer_bold_2 )
    control:Centre( wx.wxHORIZONTAL )

    --// Dialog Text
    control = wx.wxStaticText( di_tim, wx.wxID_ANY, book_number, wx.wxPoint( 0, 260 ) )
    control:SetFont( timer_bold_3 )
    control:Centre( wx.wxHORIZONTAL )

    --// Button "OK"
    local btn_close = wx.wxButton( di_tim, wx.wxID_ANY, "OK", wx.wxPoint( 0, 360 ), wx.wxSize( 90, 60 ) )
    btn_close:SetBackgroundColour( wx.wxColour( 255, 255, 255 ) )
    btn_close:Centre( wx.wxHORIZONTAL )
    btn_close:SetFont( alarm_btn )
    btn_close:SetBackgroundColour( wx.wxColour( 0, 0, 0 ) )
    btn_close:SetForegroundColour( wx.wxColour( 255, 255, 0 ) )

    --// Event - Button "OK"
    btn_close:Connect( wx.wxID_ANY, wx.wxEVT_COMMAND_BUTTON_CLICKED,
    function( event )
        media_control( mediaCtrl, "stop" ) -- mode: "play" "pause" "stop"
        di_tim:Destroy()
    end )

    --// Alarm Ton abspielen
    media_control( mediaCtrl, "play" ) -- mode: "play" "pause" "stop"

    --// Dialog anzeigen
    di_tim:ShowModal()
end

-------------------------------------------------------------------------------------------------------------------------------------
--// Diverse Helper Funktionen //----------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------

--// Dateien speichern
local save = function( config, user, book, timer )
    if config then util_savetable( cfg_tbl, "cfg_tbl", file_cfg ) end
    if user then util_savetable( user_tbl, "user_tbl", file_user ) end
    if book then util_savetable( book_tbl, "book_tbl", file_book ) end
    if timer then util_savetable( timer_tbl, "timer_tbl", file_timer ) end
end

--// check if table key exists
local tbl_key_exists = function( tbl, key )
    return tbl[ key ] ~= nil
end

--// load current signalton from table
local load_current_signaltone_selection = function()
    local file, choice
    if tbl_key_exists( cfg_tbl, "signaltone" ) then
        choice = cfg_tbl[ "signaltone" ] - 1
        file = alarm_tbl[ choice + 1 ][ 1 ]
    else
        cfg_tbl[ "signaltone" ] = 1
        file = alarm_tbl[ cfg_tbl[ "signaltone" ] ][ 2 ]
        save( true, false, false, false ) -- config, user, phonebook, timer
    end
    mediaCtrl:Load( file )
end

load_current_signaltone_selection()

--// Media Handler
media_control = function( control, mode )
    if control and mode then
        local state = control:GetState()
        local play, pause, stop = false, false, false
        if mode == "play" then
            if ( state == wx.wxMEDIASTATE_PAUSED ) or ( state == wx.wxMEDIASTATE_STOPPED ) then play = true end
        elseif mode == "pause" then
            if state == wx.wxMEDIASTATE_PLAYING then pause = true end
        elseif mode == "stop" then
            if ( state == wx.wxMEDIASTATE_PLAYING ) or ( state == wx.wxMEDIASTATE_PAUSED ) then stop = true end
        end
        if play then control:Play() end
        if pause then control:Pause() end
        if stop then control:Stop() end
    else
        return false
    end
end

--// Benutzer Validator
local check_user = function( usr )
    local err = "Bitte Beachten:\n\n\tEin Profilname muss eingetragen werden\n\tund darf max. 50 Zeichen lang sein."
    if ( usr == "" ) or ( not usr ) or ( string.len( usr ) > 50 ) then
        return false, err
    end
    return usr, err
end

--// Tabelleneinträge als sortiertes Array ausgeben
local sorted_array_user = function( tbl )
    local array = {}
    local i = 1
    for k, v in pairs( tbl ) do
        table.insert( array, i, k )
        i = i + 1
    end
    table.sort( array )
    return array
end

--// Uhrzeit Validator (NN:NN)
local check_time = function( t )
    local err = "Bitte Beachten:\n\n\tEs muss eine gültige Uhrzeit nach diesem Schema\n\teingetragen werden:  hh:mm"
    if ( t == "" ) or ( not t ) or ( string.len( t ) ~= 5 ) then
        return false, err
    end
    local hours, separator, minutes = t:sub( 1, 2 ), t:sub( 3, 3 ), t:sub( 4, 5 )
    if ( not tonumber( hours ) ) or ( tonumber( hours ) > 23 ) or ( separator ~= ":" ) or ( not tonumber( minutes ) ) or ( tonumber( minutes ) > 59 ) then
        return false, err
    end
    return t, err
end

--// Tabelleneinträge als sortiertes Array ausgeben
local sorted_array_time = function( tbl, user )
    local array = {}
    local i = 1
    if not user then return array end
    for names, tables in pairs( tbl ) do
        if names == user then
            for times, subtable in pairs( tables ) do
                table.insert( array, i, times )
                i = i + 1
            end
        end
    end
    table.sort( array )
    return array
end

--// Telefonbuch Validator
local check_book = function( name, num )
    local err = "Bitte Beachten:\n\n\tEin Name sowie eine Nummer müssen eingetragen werden\n\tund dürfen jeweils nur max. 50 Zeichen lang sein."
    if ( name == "" ) or ( not name ) or ( string.len( name ) > 50 ) then
        return false, false, err
    elseif ( num == "" ) or ( not num ) or ( string.len( num ) > 50 ) then
        return false, false, err
    end
    return name, num, err
end

--// Tabelleneinträge als sortiertes Array ausgeben (Telefonbuch)
local sorted_array_book = function( tbl )
    local array = {}
    local i = 1
    for k, v in pairs( tbl ) do
        table.insert( array, i, "Name: " .. k .. "   Nummer: " .. v )
        i = i + 1
    end
    table.sort( array )
    return array
end

-------------------------------------------------------------------------------------------------------------------------------------
--// Einstellungen Fenster //--------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------

local alarm_arr = function( tbl )
    if tbl then
        local arr = {}
        local i = 1
        for k, v in ipairs( tbl ) do
            arr[ i ] = tbl[ k ][ 2 ]
            i = i + 1
        end
        return arr
    end
end

local show_settings_window = function( frame )
    --// Dialog Fenster
    local di_set = wx.wxDialog(
        frame,
        wx.wxID_ANY,
        "Einstellungen",
        wx.wxDefaultPosition,
        wx.wxSize( 155, 280 ),
        wx.wxSTAY_ON_TOP + wx.wxDEFAULT_DIALOG_STYLE - wx.wxCLOSE_BOX - wx.wxMAXIMIZE_BOX - wx.wxMINIMIZE_BOX
    )
    di_set:SetBackgroundColour( wx.wxColour( 255, 255, 255 ) )
    di_set:SetMinSize( wx.wxSize( 155, 280 ) )
    di_set:SetMaxSize( wx.wxSize( 155, 280 ) )

	--// wxRadioBox - Signalton
	alarm_radio = wx.wxRadioBox( di_set, wx.wxID_ANY, "Signalton", wx.wxPoint( 10, 10 ), wx.wxSize( 127, 200 ), alarm_arr( alarm_tbl ), 1, wx.wxSUNKEN_BORDER )

    local current_radio_choice = cfg_tbl[ "signaltone" ] - 1
    alarm_radio:SetSelection( current_radio_choice )
    local current_radio_choice_file = alarm_tbl[ current_radio_choice + 1 ][ 1 ]
    mediaCtrl:Load( current_radio_choice_file )

	--// Event - wxRadioBox - Signalton
	alarm_radio:Connect( wx.wxID_ANY, wx.wxEVT_COMMAND_RADIOBOX_SELECTED,
	function( event )
        local choice = alarm_radio:GetSelection() + 1
        local file = alarm_tbl[ choice ][ 1 ]
        mediaCtrl:Load( file )
	end )

    --// Button "Test"
    local settings_btn_test = wx.wxButton( di_set, wx.wxID_ANY, "Test", wx.wxPoint( 12, 220 ), wx.wxSize( 60, 20 ) )
    settings_btn_test:SetBackgroundColour( wx.wxColour( 255, 255, 255 ) )

    --// Event - Button "Test"
    settings_btn_test:Connect( wx.wxID_ANY, wx.wxEVT_COMMAND_BUTTON_CLICKED,
    function( event )
        media_control( mediaCtrl, "play" ) -- mode: "play" "pause" "stop"
    end )

    --// Button "OK"
    local settings_btn_ok = wx.wxButton( di_set, wx.wxID_ANY, "OK", wx.wxPoint( 75, 220 ), wx.wxSize( 60, 20 ) )
    settings_btn_ok:SetBackgroundColour( wx.wxColour( 255, 255, 255 ) )

    --// Event - Button "OK"
    settings_btn_ok:Connect( wx.wxID_ANY, wx.wxEVT_COMMAND_BUTTON_CLICKED,
    function( event )
        local choice = alarm_radio:GetSelection() + 1
        cfg_tbl[ "signaltone" ] = choice
        save( true, false, false, false ) -- config, user, phonebook, timer
        frame:SetStatusText( "Neuer Signalton: " .. alarm_tbl[ choice ][ 2 ], 0 )
        media_control( mediaCtrl, "stop" ) -- mode: "play" "pause" "stop"
        di_set:Destroy()
    end )

    --// Dialog anzeigen
    di_set:ShowModal()
end

-------------------------------------------------------------------------------------------------------------------------------------
--// About Fenster //----------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------

local show_about_window = function( frame )
    --// Dialog Fenster
   local di_abo = wx.wxDialog(
        frame,
        wx.wxID_ANY,
        "Über" .. " " .. app_name,
        wx.wxDefaultPosition,
        wx.wxSize( 320, 395 ),
        wx.wxSTAY_ON_TOP + wx.wxDEFAULT_DIALOG_STYLE - wx.wxCLOSE_BOX - wx.wxMAXIMIZE_BOX - wx.wxMINIMIZE_BOX
    )
    di_abo:SetBackgroundColour( wx.wxColour( 255, 255, 255 ) )
    di_abo:SetMinSize( wx.wxSize( 320, 395 ) )
    di_abo:SetMaxSize( wx.wxSize( 320, 395 ) )

    --// App Logo
    local app_logo = wx.wxBitmap():ConvertToImage()
    app_logo:LoadFile( file_png_app_32 )

    control = wx.wxStaticBitmap( di_abo, wx.wxID_ANY, wx.wxBitmap( app_logo ), wx.wxPoint( 0, 15 ), wx.wxSize( app_logo:GetWidth(), app_logo:GetHeight() ) )
    control:Centre( wx.wxHORIZONTAL )
    app_logo:Destroy()

    --// App Name / Version
    control = wx.wxStaticText( di_abo, wx.wxID_ANY, app_name .. " " .. app_version, wx.wxPoint( 0, 60 ) )
    control:SetFont( about_bold )
    control:Centre( wx.wxHORIZONTAL )

    --// App Copyright
    control = wx.wxStaticText( di_abo, wx.wxID_ANY, app_copyright, wx.wxPoint( 0, 90 ) )
    control:SetFont( about_normal_2 )
    control:Centre( wx.wxHORIZONTAL )

    --// Environment
    control = wx.wxStaticText( di_abo, wx.wxID_ANY, app_env, wx.wxPoint( 0, 122 ) )
    control:SetFont( about_normal_2 )
    control:Centre( wx.wxHORIZONTAL )

    --// Build with
    control = wx.wxStaticText( di_abo, wx.wxID_ANY, app_build, wx.wxPoint( 0, 137 ) )
    control:SetFont( about_normal_2 )
    control:Centre( wx.wxHORIZONTAL )

    --// Horizontale Linie
    control = wx.wxStaticLine( di_abo, wx.wxID_ANY, wx.wxPoint( 0, 168 ), wx.wxSize( 275, 1 ) )
    control:Centre( wx.wxHORIZONTAL )

    --// License
    control = wx.wxStaticText( di_abo, wx.wxID_ANY, app_license, wx.wxPoint( 0, 180 ) )
    control:SetFont( about_normal_2 )
    control:Centre( wx.wxHORIZONTAL )

    --// GPL Logo
    local gpl_logo = wx.wxBitmap():ConvertToImage()
    gpl_logo:LoadFile( file_png_gpl )

    control = wx.wxStaticBitmap( di_abo, wx.wxID_ANY, wx.wxBitmap( gpl_logo ), wx.wxPoint( 20, 220 ), wx.wxSize( gpl_logo:GetWidth(), gpl_logo:GetHeight() ) )
    --control:Centre( wx.wxHORIZONTAL )
    gpl_logo:Destroy()

    --// OSI Logo
    local osi_logo = wx.wxBitmap():ConvertToImage()
    osi_logo:LoadFile( file_png_osi )

    control = wx.wxStaticBitmap( di_abo, wx.wxID_ANY, wx.wxBitmap( osi_logo ), wx.wxPoint( 200, 210 ), wx.wxSize( osi_logo:GetWidth(), osi_logo:GetHeight() ) )
    --control:Centre( wx.wxHORIZONTAL )
    osi_logo:Destroy()

    --// Button "Schließen"
    local about_btn_close = wx.wxButton( di_abo, wx.wxID_ANY, "Schließen", wx.wxPoint( 0, 335 ), wx.wxSize( 80, 20 ) )
    about_btn_close:SetBackgroundColour( wx.wxColour( 255, 255, 255 ) )
    about_btn_close:Centre( wx.wxHORIZONTAL )

    --// Event - Button "Schließen"
    about_btn_close:Connect( wx.wxID_ANY, wx.wxEVT_COMMAND_BUTTON_CLICKED,
    function( event )
        di_abo:Destroy()
    end )

    --// Dialog anzeigen
    di_abo:ShowModal()
end

-------------------------------------------------------------------------------------------------------------------------------------
--// Tutorial Fenster //-------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------

local show_tutorial_window = function( frame )
    --// Dialog Fenster
    local di_tut = wx.wxDialog(
        frame,
        wx.wxID_ANY,
        "Anleitung",
        wx.wxDefaultPosition,
        wx.wxSize( 450, 425 ),
        wx.wxSTAY_ON_TOP + wx.wxDEFAULT_DIALOG_STYLE - wx.wxCLOSE_BOX - wx.wxMAXIMIZE_BOX - wx.wxMINIMIZE_BOX
    )
    di_tut:SetBackgroundColour( wx.wxColour( 255, 255, 255 ) )
    di_tut:SetMinSize( wx.wxSize( 450, 425 ) )
    di_tut:SetMaxSize( wx.wxSize( 450, 425 ) )

    --// App Logo
    local app_logo = wx.wxBitmap():ConvertToImage()
    app_logo:LoadFile( file_png_app_32 )

    control = wx.wxStaticBitmap( di_tut, wx.wxID_ANY, wx.wxBitmap( app_logo ), wx.wxPoint( 0, 15 ), wx.wxSize( app_logo:GetWidth(), app_logo:GetHeight() ) )
    control:Centre( wx.wxHORIZONTAL )
    app_logo:Destroy()

    --// App Name / Version
    control = wx.wxStaticText( di_tut, wx.wxID_ANY, app_name .. " " .. app_version, wx.wxPoint( 0, 60 ) )
    control:SetFont( about_bold )
    control:Centre( wx.wxHORIZONTAL )

    --// credits
    control = wx.wxTextCtrl(
        di_tut,
        wx.wxID_ANY,
        "\n  Schritt 1 - Reiter [Profile]\n\n" ..
        "\t- Hier mindestens ein Profil hinzufügen\n\n" ..
        "  Schritt 2 - Reiter [Telefonbuch]\n\n" ..
        "\t- Damit das Programm im Erinnerungsfenster eine Nummer\n" ..
        "\t  anzeigen kann, ist es notwendig mindestens einen\n" ..
        "\t  Telefonbucheintrag hinzuzufügen.\n\n" ..
        "  Schritt 3 - Reiter [Uhrzeit]\n\n" ..
        "\t- Hier wird zuerst ein Benutzer / Objektname ausgewählt.\n" ..
        "\t- Nun kann man für den ausgewählten Eintrag die Uhrzeiten\n" ..
        "\t  hinzufügen.\n" ..
        "\t- Sind entsprechend den benötigten NSC Anrufzeiten die\n" ..
        "\t  Uhrzeiten in der Liste eingetragen muss man nur noch\n" ..
        "\t  den Timer in Tab 4 starten. Fertig.\n" ..
        "\t- Das Programm kann nun getrost minimiert werden, das\n" ..
        "\t  Erinnerungsfenster wird nun automatisch mit einem\n" ..
        "\t  akustischem Signal in den Vordergrund kommen.\n\n" ..
        "  Tipp:\n\n" ..
        "\t  Unter \"Menü / Einstellungen\" oben links gibt es eine\n" ..
        "\t  Auswahl verschiedener Alarmtöne.\n\n",
        wx.wxPoint( 5, 95 ),
        wx.wxSize( 420, 255 ),
        wx.wxTE_READONLY + wx.wxTE_MULTILINE + wx.wxTE_RICH + wx.wxSUNKEN_BORDER + wx.wxHSCROLL
    )
    --control:SetBackgroundColour( wx.wxColour( 255, 255, 255 ) )
    --control:SetForegroundColour( wx.wxBLACK )
    control:SetFont( default_font )
    control:SetBackgroundColour( wx.wxBLACK )
    control:SetForegroundColour( wx.wxColour( 255, 255, 255 ) )
    control:Centre( wx.wxHORIZONTAL )

    --// Button "Schließen"
    local settings_btn_close = wx.wxButton( di_tut, wx.wxID_ANY, "Schließen", wx.wxPoint( 0, 365 ), wx.wxSize( 80, 20 ) )
    settings_btn_close:SetBackgroundColour( wx.wxColour( 255, 255, 255 ) )
    settings_btn_close:Centre( wx.wxHORIZONTAL )

    --// Event - Button "Schließen"
    settings_btn_close:Connect( wx.wxID_ANY, wx.wxEVT_COMMAND_BUTTON_CLICKED,
    function( event )
        di_tut:Destroy()
    end )

    --// Dialog anzeigen
    di_tut:ShowModal()
end

-------------------------------------------------------------------------------------------------------------------------------------
--// Tab 1 //------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------

--// Border
control = wx.wxStaticBox( tab_1, wx.wxID_ANY, "Profil  erstellen / löschen", wx.wxPoint( 20, 10 ), wx.wxSize( 350, 337 ) )

--// wxStaticText
control = wx.wxStaticText( tab_1, wx.wxID_ANY, "Benutzername bzw. Objektname:", wx.wxPoint( 35, 36 ) )

--// wxTextCtrl
local newuser_textctrl = wx.wxTextCtrl( tab_1, wx.wxID_ANY, "", wx.wxPoint( 35, 52 ), wx.wxSize( 320, 20 ), wx.wxTE_PROCESS_ENTER + wx.wxTE_CENTRE )
newuser_textctrl:SetBackgroundColour( wx.wxColour( 255, 255, 255 ) )

--// Datenbank - Benutzer hinzufügen
local add_user = function( newuser_textctrl, user_listbox )
    local tUser = newuser_textctrl:GetValue()
    local check, err = check_user( tUser )
    if check then
        user_tbl[ tUser ] = true
        newuser_textctrl:SetValue( "" )
        save( false, true, false, false ) -- config, user, phonebook, timer
        user_listbox:Set( sorted_array_user( user_tbl ) )
        user_listbox:SetSelection( 0 )
        user_choice:Clear()
        user_choice:Append( sorted_array_user( user_tbl ) )
        time_listbox:Set( sorted_array_time( timer_tbl, user ) )
        set_timer( false, true )
        di = wx.wxMessageDialog( frame, "Profil hinzugefügt: " .. tUser, "Hinweis", wx.wxOK )
        di:ShowModal(); di:Destroy()
    else
        di = wx.wxMessageDialog( frame, "Fehler: Keine gültige Eingabe." .. "\n\n" .. err, "Hinweis", wx.wxOK )
        di:ShowModal(); di:Destroy()
    end
end

--// Datenbank - Benutzer löschen
local del_user = function( newuser_textctrl, user_listbox )
    if user_listbox:GetSelection() == -1 then
        di = wx.wxMessageDialog( frame, "Fehler: Kein Benutzer ausgewählt.", "Hinweis", wx.wxOK )
        di:ShowModal(); di:Destroy()
    else
        local tUser = user_listbox:GetString( user_listbox:GetSelection() )
        if tUser then
            user_tbl[ tUser ] = nil
            timer_tbl[ tUser ] = nil
            save( false, true, false, false ) -- config, user, phonebook, timer
            save( false, false, false, true ) -- config, user, phonebook, timer
            newuser_textctrl:SetValue( "" )
            user_listbox:Set( sorted_array_user( user_tbl ) )
            user_listbox:SetSelection( 0 )
            user_choice:Clear()
            user_choice:Append( sorted_array_user( user_tbl ) )
            time_listbox:Set( sorted_array_time( timer_tbl, user ) )
            time_listbox:SetSelection( 0 )
            set_timer( false, true )
            di = wx.wxMessageDialog( frame, "Benutzer gelöscht: " .. tUser, "Hinweis", wx.wxOK )
            di:ShowModal(); di:Destroy()
        else
            di = wx.wxMessageDialog( frame, "Benutzer nicht gefunden: " .. tUser, "Hinweis", wx.wxOK )
            di:ShowModal(); di:Destroy()
        end
    end
end

--// Border
control = wx.wxStaticBox( tab_1, wx.wxID_ANY, "", wx.wxPoint( 35, 78 ), wx.wxSize( 320, 235 ) )

--// wxListBox
user_listbox = wx.wxListBox( tab_1, wx.wxID_ANY, wx.wxPoint( 45, 93 ), wx.wxSize( 300, 212 ), sorted_array_user( user_tbl ), wx.wxLB_SINGLE + wx.wxLB_HSCROLL + wx.wxLB_SORT )
user_listbox:SetSelection( 0 ) -- ersten Eintrag markieren

--// Button "hinzufügen"
local user_add_button = wx.wxButton( tab_1, wx.wxID_ANY, "Hinzufügen", wx.wxPoint( 35, 314 ), wx.wxSize( 155, 21 ) )
user_add_button:Connect( wx.wxID_ANY, wx.wxEVT_COMMAND_BUTTON_CLICKED,
function( event )
    add_user( newuser_textctrl, user_listbox )
end )
user_add_button:Disable()

--// Button "löschen"
local user_del_button = wx.wxButton( tab_1, wx.wxID_ANY, "Löschen", wx.wxPoint( 200, 314 ), wx.wxSize( 155, 21 ) )
user_del_button:Connect( wx.wxID_ANY, wx.wxEVT_COMMAND_BUTTON_CLICKED,
function( event )
    del_user( newuser_textctrl, user_listbox )
end )

--// Event - wxTextCtrl
newuser_textctrl:Connect( wx.wxID_ANY, wx.wxEVT_COMMAND_TEXT_UPDATED,
function( event )
    user_add_button:Enable( true )
end )
newuser_textctrl:Connect( wx.wxID_ANY, wx.wxEVT_ENTER_WINDOW,
function( event )
    frame:SetStatusText( "Bitte geben sie einen Benutzernamen oder Objektnamen ein.", 0 )
end )
newuser_textctrl:Connect( wx.wxID_ANY, wx.wxEVT_LEAVE_WINDOW,
function( event )
    frame:SetStatusText( "", 0 )
end )

-------------------------------------------------------------------------------------------------------------------------------------
--// Tab 2 //------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------

--// Datenbank - Telefonbucheintrag hinzufügen
local add_book = function( newbook_name_textctrl, newbook_number_textctrl, book_listbox, book_add_button )
    local tBook_name = newbook_name_textctrl:GetValue()
    local tBook_number = newbook_number_textctrl:GetValue()
    local check_name, check_number, err = check_book( tBook_name, tBook_number )
    if check_name and check_number then
        book_tbl[ tBook_name ] = tBook_number
        save( false, false, true, false ) -- config, user, phonebook, timer
        newbook_name_textctrl:SetValue( "" )
        newbook_number_textctrl:SetValue( "" )
        book_listbox:Set( sorted_array_book( book_tbl ) )
        book_listbox:SetSelection( 0 )
        book_add_button:Disable()
        di = wx.wxMessageDialog( frame, "Eintrag hinzugefügt:\n\nName:\t" .. tBook_name .. "\nNummer:\t" .. tBook_number, "Hinweis", wx.wxOK )
        di:ShowModal(); di:Destroy()
    else
        di = wx.wxMessageDialog( frame, "Fehler: Keine gültige Eingabe." .. "\n\n" .. err, "Hinweis", wx.wxOK )
        di:ShowModal(); di:Destroy()
    end
end

--// Datenbank - Telefonbucheintrag löschen
local del_book = function( newbook_name_textctrl, newbook_number_textctrl, book_listbox )
    if book_listbox:GetSelection() == -1 then
        di = wx.wxMessageDialog( frame, "Fehler: Kein Eintrag ausgewählt.", "Hinweis", wx.wxOK )
        di:ShowModal(); di:Destroy()
    else
        local tBook = book_listbox:GetString( book_listbox:GetSelection() )
        if tBook then
            local n, _ = string.find( tBook, "Nummer:" ); n = n - 4
            local s = string.sub( tBook, 7, n )
            book_tbl[ s ] = nil
            save( false, false, true, false ) -- config, user, phonebook, timer
            newbook_name_textctrl:SetValue( "" )
            newbook_number_textctrl:SetValue( "" )
            book_listbox:Set( sorted_array_book( book_tbl ) )
            book_listbox:SetSelection( 0 )
            di = wx.wxMessageDialog( frame, "Eintrag gelöscht: " .. tBook, "Hinweis", wx.wxOK )
            di:ShowModal(); di:Destroy()
        end
    end
end

--// Border
control = wx.wxStaticBox( tab_2, wx.wxID_ANY, "Neuer Telefonbucheintrag", wx.wxPoint( 20, 10 ), wx.wxSize( 350, 337 ) )

--// wxStaticText - Name
control = wx.wxStaticText( tab_2, wx.wxID_ANY, "NSC Name:", wx.wxPoint( 35, 36 ) )

--// wxTextCtrl - Name
local newbook_name_textctrl = wx.wxTextCtrl( tab_2, wx.wxID_ANY, "", wx.wxPoint( 35, 52 ), wx.wxSize( 320, 20 ), wx.wxTE_PROCESS_ENTER + wx.wxTE_CENTRE )
newbook_name_textctrl:SetBackgroundColour( wx.wxColour( 255, 255, 255 ) )

--// wxStaticText - Nummer
control = wx.wxStaticText( tab_2, wx.wxID_ANY, "NSC Nummer:", wx.wxPoint( 35, 76 ) )

--// wxTextCtrl - Nummer
local newbook_number_textctrl = wx.wxTextCtrl( tab_2, wx.wxID_ANY, "", wx.wxPoint( 35, 92 ), wx.wxSize( 320, 20 ), wx.wxTE_PROCESS_ENTER + wx.wxTE_CENTRE )
newbook_name_textctrl:SetBackgroundColour( wx.wxColour( 255, 255, 255 ) )

--// Border
control = wx.wxStaticBox( tab_2, wx.wxID_ANY, "", wx.wxPoint( 35, 118 ), wx.wxSize( 320, 195 ) )

--// wxListBox
local book_listbox = wx.wxListBox( tab_2, wx.wxID_ANY, wx.wxPoint( 45, 133 ), wx.wxSize( 300, 172 ), sorted_array_book( book_tbl ), wx.wxLB_SINGLE + wx.wxLB_HSCROLL + wx.wxLB_SORT )
book_listbox:SetSelection( 0 ) -- ersten Eintrag markieren

--// Button "hinzufügen"
local book_add_button = wx.wxButton( tab_2, wx.wxID_ANY, "Hinzufügen", wx.wxPoint( 35, 314 ), wx.wxSize( 155, 21 ) )
book_add_button:Disable()

--// Button "löschen"
local book_del_button = wx.wxButton( tab_2, wx.wxID_ANY, "Löschen", wx.wxPoint( 200, 314 ), wx.wxSize( 155, 21 ) )

--// Event - Button "hinzufügen"
book_add_button:Connect( wx.wxID_ANY, wx.wxEVT_COMMAND_BUTTON_CLICKED,
function( event )
    add_book( newbook_name_textctrl, newbook_number_textctrl, book_listbox, book_add_button )
end )

--// Event - Button "löschen"
book_del_button:Connect( wx.wxID_ANY, wx.wxEVT_COMMAND_BUTTON_CLICKED,
function( event )
    del_book( newbook_name_textctrl, newbook_number_textctrl, book_listbox )
end )

--// Event - wxTextCtrl - Name
newbook_name_textctrl:Connect( wx.wxID_ANY, wx.wxEVT_COMMAND_TEXT_UPDATED,
function( event )
    if newbook_number_textctrl:GetValue() ~= "" then book_add_button:Enable( true ) end
end )
newbook_name_textctrl:Connect( wx.wxID_ANY, wx.wxEVT_ENTER_WINDOW,
function( event )
    frame:SetStatusText( "Namen des (N)otruf (S)ervice (C)enters eingeben.", 0 )
end )
newbook_name_textctrl:Connect( wx.wxID_ANY, wx.wxEVT_LEAVE_WINDOW,
function( event )
    frame:SetStatusText( "", 0 )
end )

--// Event - wxTextCtrl - Nummer
newbook_number_textctrl:Connect( wx.wxID_ANY, wx.wxEVT_COMMAND_TEXT_UPDATED,
function( event )
    if newbook_name_textctrl:GetValue() ~= "" then book_add_button:Enable( true ) end
end )
newbook_number_textctrl:Connect( wx.wxID_ANY, wx.wxEVT_ENTER_WINDOW,
function( event )
    frame:SetStatusText( "Nummer des (N)otruf (S)ervice (C)enters eingeben.", 0 )
end )
newbook_number_textctrl:Connect( wx.wxID_ANY, wx.wxEVT_LEAVE_WINDOW,
function( event )
    frame:SetStatusText( "", 0 )
end )

-------------------------------------------------------------------------------------------------------------------------------------
--// Tab 3 //------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------

--// Border
control = wx.wxStaticBox( tab_3, wx.wxID_ANY, "Profil auswählen:", wx.wxPoint( 20, 10 ), wx.wxSize( 350, 55 ) )

--// wxChoice - Benutzer wählen
user_choice = wx.wxChoice(
    tab_3,
    wx.wxID_ANY,
    wx.wxPoint( 35, 30 ),
    wx.wxSize( 320, 20 ),
    sorted_array_user( user_tbl )
)
user_choice:Select( -1 )

--// Border
control = wx.wxStaticBox( tab_3, wx.wxID_ANY, "Uhrzeiten  eintragen / löschen", wx.wxPoint( 20, 80 ), wx.wxSize( 350, 267 ) )

--// wxStaticText
control = wx.wxStaticText( tab_3, wx.wxID_ANY, "Schema: hh:mm", wx.wxPoint( 35, 101 ) )

--// wxTextCtrl
local newtime_textctrl = wx.wxTextCtrl( tab_3, wx.wxID_ANY, "", wx.wxPoint( 35, 117 ), wx.wxSize( 320, 20 ), wx.wxTE_PROCESS_ENTER + wx.wxTE_CENTRE )
newtime_textctrl:SetBackgroundColour( wx.wxColour( 255, 255, 255 ) )

--// wxTextCtrl - Events
newtime_textctrl:Connect( wx.wxID_ANY, wx.wxEVT_KILL_FOCUS,
function( event )
    local s = newtime_textctrl:GetValue()
    local new, n = string.gsub( s, " ", "" )
    if n ~= 0 then
        --// Dialog Fenster
        local mdi = wx.wxMessageDialog( frame, "Fehler: Leerstellen nicht erlaubt.\n\nEntfernte Leerstellen: " .. n, "Warnung", wx.wxOK )
        mdi:ShowModal(); mdi:Destroy()
        newtime_textctrl:SetValue( new )
    end
end )
newtime_textctrl:Connect( wx.wxID_ANY, wx.wxEVT_ENTER_WINDOW,
function( event )
    frame:SetStatusText( "Eine gültige Uhrzeit eingeben. (hh:mm)   Beispiel: 18:00", 0 )
end )
newtime_textctrl:Connect( wx.wxID_ANY, wx.wxEVT_LEAVE_WINDOW,
function( event )
    frame:SetStatusText( "", 0 )
end )

--// Border
control = wx.wxStaticBox( tab_3, wx.wxID_ANY, "", wx.wxPoint( 35, 143 ), wx.wxSize( 320, 170 ) )

--// wxListBox
time_listbox = wx.wxListBox( tab_3, wx.wxID_ANY, wx.wxPoint( 45, 158 ), wx.wxSize( 300, 147 ), sorted_array_time( timer_tbl ), wx.wxLB_SINGLE + wx.wxLB_HSCROLL + wx.wxLB_SORT + wx.wxSUNKEN_BORDER )
time_listbox:SetSelection( 0 ) -- ersten Eintrag markieren
time_listbox:SetFont( timer_list )

--// Button "hinzufügen"
local time_add_button = wx.wxButton( tab_3, wx.wxID_ANY, "Hinzufügen", wx.wxPoint( 35, 314 ), wx.wxSize( 155, 21 ) )
time_add_button:Disable()

--// Button "löschen"
local time_del_button = wx.wxButton( tab_3, wx.wxID_ANY, "Löschen", wx.wxPoint( 200, 314 ), wx.wxSize( 155, 21 ) )

--// Datenbank - Uhrzeit eintragen
local add_time = function( user, textctrl, listbox, book_name, book_number )
    local tTime = textctrl:GetValue()
    local check, err = check_time( tTime )
    local new_user, time_exists, overwrite, need_save = false, false, false, false
    if check then
        if not tbl_key_exists( timer_tbl, user ) then
            new_user = true
        else
            for k, v in pairs( timer_tbl ) do
                if ( k == user ) and ( tbl_key_exists( v, tTime ) ) then time_exists = true end
            end
        end
        if new_user then
            timer_tbl[ user ] = {}
            timer_tbl[ user ][ tTime ] = {}
            timer_tbl[ user ][ tTime ][ book_name ] = book_number
            need_save = true
        else
            if time_exists then
                --// Dialog Fenster
                di = wx.wxMessageDialog( frame, "Ein Eintrag mit dieser Uhrzeit existiert bereits.\n\nÜberschreiben?", "Hinweis", wx.wxYES_NO + wx.wxICON_QUESTION + wx.wxCENTRE )
                result = di:ShowModal(); di:Destroy()
                if result == wx.wxID_YES then overwrite = true end
            end
            if not time_exists or overwrite then
                timer_tbl[ user ][ tTime ] = {}
                timer_tbl[ user ][ tTime ][ book_name ] = book_number
                need_save = true
            end
        end
        if need_save then
            save( false, false, false, true ) -- config, user, phonebook, timer
            textctrl:SetValue( "" )
            listbox:Set( sorted_array_time( timer_tbl, user ) )
            listbox:SetSelection( 0 )
            user_choice:Update( sorted_array_user( user_tbl ) )
            --// Dialog Fenster
            di = wx.wxMessageDialog( frame, "Profil:\t\t" .. user .. "\nUhrzeit:\t\t" .. tTime .. "\n\nNSC Name:\t" .. book_name .. "\nNSC Nummer:\t" .. book_number, "Hinweis", wx.wxOK )
            di:ShowModal(); di:Destroy()
            time_add_button:Disable()
            set_timer( false, true )
        end
    else
        newtime_textctrl:SetValue( "" )
        di = wx.wxMessageDialog( frame, "Fehler: Keine gültige Eingabe." .. "\n\n" .. err, "Hinweis", wx.wxOK )
        di:ShowModal(); di:Destroy()
        time_add_button:Disable()
    end
end

--// Datenbank - Uhrzeit löschen
local del_time = function( user, newtime_textctrl, time_listbox )
    if time_listbox:GetSelection() == -1 then
        di = wx.wxMessageDialog( frame, "Fehler: Keine Uhrzeit ausgewählt.", "Hinweis", wx.wxOK )
        di:ShowModal(); di:Destroy()
    else
        local user = user_choice:GetStringSelection()
        local tTime = time_listbox:GetString( time_listbox:GetSelection() )
        if tTime then timer_tbl[ user ][ tTime ] = nil end -- Eintrag löschen
        save( false, false, false, true ) -- config, user, phonebook, timer
        newtime_textctrl:SetValue( "" )
        time_listbox:Set( sorted_array_time( timer_tbl, user ) )
        time_listbox:SetSelection( 0 )
        set_timer( false, true )
        di = wx.wxMessageDialog( frame, "Uhrzeit gelöscht: " .. tTime, "Hinweis", wx.wxOK )
        di:ShowModal(); di:Destroy()
    end
end

--// Event - Button "hinzufügen"
time_add_button:Connect( wx.wxID_ANY, wx.wxEVT_COMMAND_BUTTON_CLICKED,
function( event )
    local choice = tonumber( user_choice:GetCurrentSelection() )
    if choice == -1 then
        di = wx.wxMessageDialog( frame, "Fehler: Kein Profil ausgewählt.", "Hinweis", wx.wxOK )
        di:ShowModal(); di:Destroy()
    elseif next( book_tbl ) == nil then
        di = wx.wxMessageDialog( frame, "Fehler: Es sind noch keine Telefonbucheinträge vorhanden.", "Hinweis", wx.wxOK )
        di:ShowModal(); di:Destroy()
    else
        local user = user_choice:GetStringSelection()
        local book_name, book_number

        --// Dialog Fenster
        di = wx.wxDialog( frame, wx.wxID_ANY, "NSC Leitstelle auswählen:", wx.wxDefaultPosition, wx.wxSize( 245, 100 ), wx.wxSTAY_ON_TOP + wx.wxDEFAULT_DIALOG_STYLE - wx.wxCLOSE_BOX - wx.wxMAXIMIZE_BOX - wx.wxMINIMIZE_BOX )
        di:SetBackgroundColour( wx.wxColour( 255, 255, 255 ) )
        di:SetMinSize( wx.wxSize( 245, 100 ) )
        di:SetMaxSize( wx.wxSize( 245, 100 ) )

        --// wxChoice - Benutzer wählen
        local book_choice = wx.wxChoice(
            di,
            wx.wxID_ANY,
            wx.wxPoint( 10, 10 ),
            wx.wxSize( 218, 20 ),
            sorted_array_user( book_tbl )
        )
        book_choice:Select( 0 )

        --// Button "OK"
        local btn_close = wx.wxButton( di, wx.wxID_ANY, "OK", wx.wxPoint( 0, 42 ), wx.wxSize( 80, 20 ) )
        btn_close:SetBackgroundColour( wx.wxColour( 255, 255, 255 ) )
        btn_close:Centre( wx.wxHORIZONTAL )

        --// Event - Button "OK"
        btn_close:Connect( wx.wxID_ANY, wx.wxEVT_COMMAND_BUTTON_CLICKED,
        function( event )
            local entry = book_choice:GetStringSelection()
            for k, v in pairs( book_tbl ) do
                if k == entry then book_name = k; book_number = v; break end
            end
            di:Destroy()
        end )
        di:ShowModal()

        add_time( user, newtime_textctrl, time_listbox, book_name, book_number )
    end
end )

--// Event - Button "löschen"
time_del_button:Connect( wx.wxID_ANY, wx.wxEVT_COMMAND_BUTTON_CLICKED,
function( event )
    local user = user_choice:GetStringSelection()
    del_time( user, newtime_textctrl, time_listbox )
    set_timer( false, true )
end )

--// Event - user_choice
user_choice:Connect( wx.wxID_ANY, wx.wxEVT_COMMAND_CHOICE_SELECTED,
function( event )
    if newtime_textctrl:GetValue() ~= "" then
        time_add_button:Enable( true )
    end
    local user = user_choice:GetStringSelection()
    time_listbox:Set( sorted_array_time( timer_tbl, user ) )
    set_timer( false, true )
end )

--// Event - wxTextCtrl - Button "hinzufügen"
newtime_textctrl:Connect( wx.wxID_ANY, wx.wxEVT_COMMAND_TEXT_UPDATED,
function( event )
    local choice = tonumber( user_choice:GetCurrentSelection() )
    if ( newtime_textctrl:GetValue() ~= "" ) and ( choice ~= -1 ) then
        time_add_button:Enable( true )
    end
end )

-------------------------------------------------------------------------------------------------------------------------------------
--// Tab 4 //------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------

--// Border
control = wx.wxStaticBox( tab_4, wx.wxID_ANY, "Timer Status", wx.wxPoint( 50, 85 ), wx.wxSize( 290, 167 ) )

--// wxTextCtrl
status_textctrl = wx.wxTextCtrl( tab_4, wx.wxID_ANY, "", wx.wxPoint( 62, 105 ), wx.wxSize( 266, 28 ), wx.wxTE_READONLY + wx.wxTE_CENTRE )-- + wx.wxNO_BORDER )
status_textctrl:SetBackgroundColour( wx.wxColour( 40, 40, 40 ) )
status_textctrl:SetFont( timer_status )
status_textctrl:SetForegroundColour( wx.wxColour( 255, 0, 0 ) )
status_textctrl:SetValue( ">  D E A K T I V I E R T  <" )

--// Button - Timer start
timer_start_button = wx.wxButton( tab_4, wx.wxID_ANY, "START", wx.wxPoint( 62, 143 ), wx.wxSize( 130, 98 ) )
timer_start_button:SetBackgroundColour( wx.wxColour( 180, 180, 180 ) )
timer_start_button:SetFont( timer_btn )
--// Button - Timer stop
timer_stop_button = wx.wxButton( tab_4, wx.wxID_ANY, "STOP", wx.wxPoint( 197, 143 ), wx.wxSize( 130, 98 ) )
timer_stop_button:SetBackgroundColour( wx.wxColour( 180, 180, 180 ) )
timer_stop_button:SetFont( timer_btn )
--// Button - Timer start - Event
timer_start_button:Connect( wx.wxID_ANY, wx.wxEVT_COMMAND_BUTTON_CLICKED,
function( event )
    set_timer( true, false )
end )

--// Button - Timer stop - Event
timer_stop_button:Disable()
timer_stop_button:Connect( wx.wxID_ANY, wx.wxEVT_COMMAND_BUTTON_CLICKED,
function( event )
    set_timer( false, false )
end )

--// blinking eye catcher
local show_status_text = false

local status_blink = function( status_textctrl )
    if show_status_text then
        status_textctrl:SetValue( ">     A K T I V I E R T     <" )
        show_status_text = false
    else
        status_textctrl:SetValue( "" )
        show_status_text = true
    end
end

--[[
--// DEBUG - Button - Test Alert Window
timer_test_alert = wx.wxButton( tab_4, wx.wxID_ANY, "TEST", wx.wxPoint( 5, 340 ), wx.wxSize( 50, 20 ) )
timer_test_alert:SetBackgroundColour( wx.wxColour( 255, 255, 0 ) )
timer_test_alert:Connect( wx.wxID_ANY, wx.wxEVT_COMMAND_BUTTON_CLICKED,
function( event )
    show_alert_window( "18:00", "MAN Diesel", "0821 - 11 22 33 44 55"  )
end )
]]

-------------------------------------------------------------------------------------------------------------------------------------
--// MAIN LOOP //--------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------

--// Event - Timer
panel:Connect( wx.wxEVT_TIMER, -- timer iteration
function( event )
    local time = os.date( "%H:%M" )
    local book_name, book_number = get_current_time_infos( time )
    if book_name then
        show_alert_window( time, book_name, book_number )
    end
    status_blink( status_textctrl )
end )

main = function()
    frame:Show( true )
    frame:Connect( wx.wxEVT_CLOSE_WINDOW,
    function( event )
        --// Dialog Fenster
        di = wx.wxMessageDialog( frame, "Wirklich beenden?", "Hinweis", wx.wxYES_NO + wx.wxICON_QUESTION + wx.wxCENTRE )
        result = di:ShowModal(); di:Destroy()
        if result == wx.wxID_YES then
            event:Skip()
            if timer then timer:Stop(); timer:delete(); timer = nil end
            frame:Destroy()
        end
    end )
    --// menu bar events
    frame:Connect( wx.wxID_EXIT, wx.wxEVT_COMMAND_MENU_SELECTED,
    function( event )
        frame:Close( true )
    end )
    frame:Connect( ID_mb_settings, wx.wxEVT_COMMAND_MENU_SELECTED,
    function( event )
        show_settings_window( frame )
    end )
    frame:Connect( wx.wxID_ABOUT, wx.wxEVT_COMMAND_MENU_SELECTED,
    function( event )
        show_about_window( frame )
    end )
    frame:Connect( ID_mb_tutorial, wx.wxEVT_COMMAND_MENU_SELECTED,
    function( event )
        show_tutorial_window( frame )
    end )
end

main()
wx.wxGetApp():MainLoop()