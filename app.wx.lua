--[[

    NSC Tool

        Author:       Benjamin Kupka
        License:      GNU GPLv3
        Environment:  wxLua-2.8.12.3-Lua-5.1.5-MSW-Unicode

        Beschreibung:

            Das Tool erinnert akustisch an die notwendigen Telefonate an die zuständige Serviceleitstelle.
            Die für die akustischen Erinnerungen notwendigen Zeiten lassen sich übersichtlich in Profilen
            verwalten.


        Dieses Projekt ist unter GPLv3 lizensiert, für mehr Informationen: 'docs/LICENSE'.
        Die Versionshistory (Changelog): 'docs/CHANGELOG'.

]]

-------------------------------------------------------------------------------------------------------------------------------------
--// IMPORTS //----------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------

--// import path constants
dofile( "data/cfg/const.lua" )

--// lib path
package.path = ";./" .. LUALIB_PATH .. "?.lua" ..
               ";./" .. CORE_PATH .. "?.lua"

package.cpath = ";./" .. CLIB_PATH .. "?.dll"

--// libs
local wx   = require( "wx" )
local util = require( "util" )

-------------------------------------------------------------------------------------------------------------------------------------
--// TABLE LOOKUPS //----------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------

local util_loadtable = util.loadtable
local util_savetable = util.savetable

-------------------------------------------------------------------------------------------------------------------------------------
--// BASICS //-----------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------

--// app vars
local app_name         = "NSC Tool"
local app_version      = "v0.5"
local app_copyright    = "Copyright (C) 2018 by Benjamin Kupka"
local app_license      = "GNU General Public License Version 3"
local app_env          = "Environment: " .. wxlua.wxLUA_VERSION_STRING
local app_build        = "Built with: "..wx.wxVERSION_STRING

local app_width        = 405
local app_height       = 470

local notebook_width   = app_width - 6
local notebook_height  = app_height - 79

--// do not touch
local timer_i          = 1000 -- timer Intervall (1 second)
local timer_m          = false -- timer mode; false = endless timer / true = one time (oneShot)
local alarmtime_done   = ""
local slider_range     = 100
local exec             = true
local gauge_max_range  = 100
local gauge_seconds    = 0

--// files
local db_tbl = {

    [ 1 ] = CFG_PATH .. "cfg.tbl",
    [ 2 ] = DB_PATH ..  "user.tbl",
    [ 3 ] = DB_PATH ..  "book.tbl",
    [ 4 ] = DB_PATH ..  "timer.tbl",
}
local png_tbl = {

    [ 1 ] = RES_PATH .. "GPLv3_160x80.png",
    [ 2 ] = RES_PATH .. "osi_75x100.png",
    [ 3 ] = RES_PATH .. "appicon_16x16.png",
    [ 4 ] = RES_PATH .. "appicon_32x32.png",
    [ 5 ] = RES_PATH .. "user.png",
    [ 6 ] = RES_PATH .. "phonebook.png",
    [ 7 ] = RES_PATH .. "clock.png",
    [ 8 ] = RES_PATH .. "timer.png",
}
local audio_tbl = {

    [ 1 ] = { RES_PATH .. "AlarmClock.mp3",     "AlarmClock" },
    [ 2 ] = { RES_PATH .. "AnalogWatch.mp3",    "AnalogWatch" },
    [ 3 ] = { RES_PATH .. "HouseFireAlarm.mp3", "HouseFireAlarm" },
    [ 4 ] = { RES_PATH .. "MetalMetronome.mp3", "MetalMetronome" },
    [ 5 ] = { RES_PATH .. "MissileAlert.mp3",   "MissileAlert" },
    [ 6 ] = { RES_PATH .. "OldBell.mp3",        "OldBell" },
    [ 7 ] = { RES_PATH .. "OldFashionDoor.mp3", "OldFashionDoor" },
    [ 8 ] = { RES_PATH .. "RoosterCrow.mp3",    "RoosterCrow" },
    [ 9 ] = { RES_PATH .. "TornadoSiren.mp3",   "TornadoSiren" },
}

--// import database
local cfg_tbl   = util_loadtable( db_tbl[ 1 ] ) or {}
local user_tbl  = util_loadtable( db_tbl[ 2 ] ) or {}
local book_tbl  = util_loadtable( db_tbl[ 3 ] ) or {}
local timer_tbl = util_loadtable( db_tbl[ 4 ] ) or {}

--// Fonts
local default_font     = wx.wxFont( 8,  wx.wxMODERN, wx.wxNORMAL, wx.wxNORMAL, false, "Verdana" )
local about_normal_1   = wx.wxFont( 9,  wx.wxMODERN, wx.wxNORMAL, wx.wxNORMAL, false, "Verdana" )
local about_normal_2   = wx.wxFont( 10, wx.wxMODERN, wx.wxNORMAL, wx.wxNORMAL, false, "Verdana" )
local about_bold       = wx.wxFont( 10, wx.wxMODERN, wx.wxNORMAL, wx.wxFONTWEIGHT_BOLD, false, "Verdana" )
local timer_bold       = wx.wxFont( 14, wx.wxMODERN, wx.wxNORMAL, wx.wxFONTWEIGHT_BOLD, false, "Verdana" )
local timer_bold_2     = wx.wxFont( 18, wx.wxMODERN, wx.wxNORMAL, wx.wxFONTWEIGHT_BOLD, false, "Verdana" )
local timer_bold_3     = wx.wxFont( 22, wx.wxMODERN, wx.wxNORMAL, wx.wxFONTWEIGHT_BOLD, false, "Verdana" )
local timer_list       = wx.wxFont( 10, wx.wxMODERN, wx.wxNORMAL, wx.wxFONTWEIGHT_BOLD, false, "Verdana" )
local timer_status     = wx.wxFont( 13, wx.wxMODERN, wx.wxNORMAL, wx.wxFONTWEIGHT_BOLD, false, "Verdana" )
local timer_choice     = wx.wxFont( 9,  wx.wxMODERN, wx.wxNORMAL, wx.wxFONTWEIGHT_BOLD, false, "Verdana" )
local timer_btn        = wx.wxFont( 18, wx.wxMODERN, wx.wxNORMAL, wx.wxNORMAL, false, "Verdana" )
local alarm_btn        = wx.wxFont( 18, wx.wxMODERN, wx.wxNORMAL, wx.wxFONTWEIGHT_BOLD, false, "Verdana" )

--// controls
local control, di, result
local id_counter
local frame
local panel
local notebook
local tab_1, tab_2, tab_3, tab_4
local timer
local media_ctrl
local newuser_textctrl -- tab 1
local user_listbox -- tab 1
local user_add_button -- tab 1
local user_del_button -- tab 1
local newbook_name_textctrl -- tab 2
local newbook_number_textctrl -- tab 2
local book_listbox -- tab 2
local book_add_button -- tab 2
local book_del_button -- tab 2
local user_choice -- tab 3
local newtime_textctrl -- tab 3
local time_listbox -- tab 3
local time_add_button -- tab 3
local time_del_button -- tab 3
local status_textctrl -- tab 4
local timer_start_button -- tab 4
local timer_stop_button -- tab 4
local timer_current_profile -- tab 4
local timer_remaining_time -- tab 4
local timer_gauge -- tab 4

--// functions
local new_id
local errorlog
local show_error_window
local check_files_exists
local save
local get_current_time_infos
local set_timer
local tbl_key_exists
local load_current_signaltone_selection
local media_control
local check_user
local sorted_array_user
local sorted_array_time
local sorted_array_book
local sorted_array_audio
local check_time
local check_book
local get_next_time
local menu_item
local show_alert_window
local show_about_window
local show_settings_window
local show_tutorial_window
local add_user -- tab 1
local del_user -- tab 1
local add_book -- tab 2
local del_book -- tab 2
local add_time -- tab 3
local del_time -- tab 3
local status_blink -- tab 4

-------------------------------------------------------------------------------------------------------------------------------------
--// IDS //--------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------

--// ID generator
id_counter = wx.wxID_HIGHEST + 1
new_id = function() id_counter = id_counter + 1; return id_counter end

--// IDs
ID_mb_settings = new_id()
ID_mb_tutorial = new_id()

-------------------------------------------------------------------------------------------------------------------------------------
--// HELPER FUNCS //-----------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------

--// add error to file / make error file if not exists
errorlog = function( msg )
    local filename = "ERROR.txt"; local f = io.open( filename, "a" )
    f:write( os.date( "[%Y-%m-%d / %H:%M Uhr] " ) .. msg .. "\n" ); f:close()
end

--// error Window
show_error_window = function( err )
    di = wx.wxMessageDialog(
        wx.NULL,
        "Folgende Datei kann nicht gefunden werden:\n\n" ..
        "[ " .. err .. " ]\n\n" ..
        "Programm wird beendet.\n" ..
        "Bitte neu Downloaden.",
        "FEHLER",
        wx.wxOK + wx.wxICON_ERROR + wx.wxCENTRE
    )
    result = di:ShowModal(); di:Destroy()
    if result == wx.wxID_OK then
        errorlog( "Datei nicht gefunden: " .. err )
        if event then event:Skip() end
        if timer then timer:Stop(); timer:delete(); timer = nil end
        if frame then frame:Destroy() end
        exec = false
        return nil
    end
end

--// check if files exists
check_files_exists = function( tbl )
    for k, v in ipairs( tbl ) do
        if type( v ) ~= "table" then
            if not wx.wxFile.Exists( v ) then return show_error_window( v ) end
        else
            if not wx.wxFile.Exists( v[ 1 ] ) then return show_error_window( v[ 1 ] ) end
        end
    end
end

check_files_exists( png_tbl )
check_files_exists( audio_tbl )

--// save tables
save = function( config, user, book, timer )
    if config then util_savetable( cfg_tbl, "cfg_tbl", db_tbl[ 1 ] ) end
    if user then util_savetable( user_tbl, "user_tbl", db_tbl[ 2 ] ) end
    if book then util_savetable( book_tbl, "book_tbl", db_tbl[ 3 ] ) end
    if timer then util_savetable( timer_tbl, "timer_tbl", db_tbl[ 4 ] ) end
end

--// check if its time for the alarm windows
get_current_time_infos = function( t, user )
    for names, v in pairs( timer_tbl ) do
        if names == user then
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

--// toggle timer on/off
set_timer = function( mode, dialog ) -- mode: timer on/off (bool); dialog: send dialog if timer is off (bool)
    if mode then
        if not timer:IsRunning() then
            timer:Start( timer_i, timer_m )
            frame:SetStatusText( "Timer: AN", 1 )
            if dialog then
                di = wx.wxMessageDialog( frame, "Der Timer wurde gestartet.", "Hinweis", wx.wxOK )
                di:ShowModal(); di:Destroy()
            end
        end
    else
        if timer:IsRunning() then
            timer:Stop()
            frame:SetStatusText( "Timer: AUS", 1 )
            if dialog then
                di = wx.wxMessageDialog( frame, "Der Timer wurde gestoppt.", "Hinweis", wx.wxOK )
                di:ShowModal(); di:Destroy()
            end
        end
    end
end

--// check if table key exists
tbl_key_exists = function( tbl, key )
    return tbl[ key ] ~= nil
end

--// check if table is empty
local tbl_is_empty = function( tbl )
    if next( tbl ) == nil then return true else return false end
end

--// load current signalton from table
load_current_signaltone_selection = function( media_ctrl )
    local file, choice, volume
    local need_save = false
    if tbl_key_exists( cfg_tbl, "signaltone" ) then
        choice = cfg_tbl[ "signaltone" ] - 1
        file = audio_tbl[ choice + 1 ][ 1 ]
    else
        cfg_tbl[ "signaltone" ] = 2
        file = audio_tbl[ cfg_tbl[ "signaltone" ] ][ 2 ]
        need_save = true
    end
    if tbl_key_exists( cfg_tbl, "volume" ) then
        volume = cfg_tbl[ "volume" ]
    else
        volume = 1
        cfg_tbl[ "volume" ] = volume
        need_save = true
    end
    media_ctrl:Load( file )
    media_ctrl:SetVolume( volume )
    if need_save then
        save( true, false, false, false ) -- config, user, phonebook, timer
    end
end

--// media handler
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

--// user validator
check_user = function( usr )
    local err = "Bitte Beachten:\n\n\tEin Profilname muss eingetragen werden\n\tund darf max. 50 Zeichen lang sein."
    if ( usr == "" ) or ( not usr ) or ( string.len( usr ) > 50 ) then
        return false, err
    end
    return usr, err
end

--// sorted user array
sorted_array_user = function( tbl )
    local array = {}
    local i = 1
    for k, v in pairs( tbl ) do
        table.insert( array, i, k )
        i = i + 1
    end
    table.sort( array )
    return array
end

--// sorted times array
sorted_array_time = function( tbl, user )
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

--// sorted phone array
sorted_array_book = function( tbl )
    local array = {}
    local i = 1
    for k, v in pairs( tbl ) do
        table.insert( array, i, "Name: " .. k .. "   Nummer: " .. v )
        i = i + 1
    end
    table.sort( array )
    return array
end

--// sorted audio files array
sorted_array_audio = function( tbl )
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

--// time validator (NN:NN)
check_time = function( t )
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

--// phone validator
check_book = function( name, num )
    local err = "Bitte Beachten:\n\n\tEin Name sowie eine Nummer müssen eingetragen werden\n\tund dürfen jeweils nur max. 50 Zeichen lang sein."
    if ( name == "" ) or ( not name ) or ( string.len( name ) > 50 ) then
        return false, false, err
    elseif ( num == "" ) or ( not num ) or ( string.len( num ) > 50 ) then
        return false, false, err
    end
    return name, num, err
end

--// get the remaining time as string
get_next_time = function( timer_tbl, user )
    if ( user ~= "" or user ~= nil ) then
        if not tbl_is_empty( timer_tbl ) then
            local seconds_to_wait = 99999999999
            local time_next = ""
            local t_day   = os.date("%d")
            local t_month = os.date("%m")
            local t_year  = os.date("%Y")
            for names, v in pairs( timer_tbl ) do
                if names == user then
                    for tTime, tbl in pairs( v ) do
                        local t_hour = tTime:sub( 1, 2 )
                        local t_min  = tTime:sub( 4, 5 )
                        local t_time = os.time( { year = t_year, month = t_month, day = t_day, hour = t_hour, min = t_min } )
                        local seconds = os.difftime( t_time, os.time() )
                        if type( seconds ) == "number" then
                            if ( seconds > 0 ) and ( seconds < seconds_to_wait ) then
                                seconds_to_wait = seconds
                                time_next = tTime
                            end
                        end
                    end
                end
            end
            local d, h, m, s = util.formatseconds( seconds_to_wait )
            local h_var, m_var, s_var
            if h == 1 then h_var = " Stunde, " else h_var = " Stunden, " end
            if m == 1 then m_var = " Minute, " else m_var = " Minuten, " end
            if s == 1 then s_var = " Sekunde"  else s_var = " Sekunden"  end
            return time_next, h .. h_var .. m .. m_var .. s .. s_var, seconds_to_wait
        else
            return "?", "?"
        end
    else
        return "?", "?"
    end
end

-------------------------------------------------------------------------------------------------------------------------------------
--// MENUBAR //----------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------

local bmp_settings_16x16 = wx.wxArtProvider.GetBitmap( wx.wxART_LIST_VIEW,   wx.wxART_TOOLBAR )
local bmp_exit_16x16     = wx.wxArtProvider.GetBitmap( wx.wxART_QUIT,        wx.wxART_TOOLBAR )
local bmp_about_16x16    = wx.wxArtProvider.GetBitmap( wx.wxART_INFORMATION, wx.wxART_TOOLBAR )
local bmp_tutorial_16x16 = wx.wxArtProvider.GetBitmap( wx.wxART_INFORMATION, wx.wxART_TOOLBAR )

menu_item = function( menu, id, name, status, bmp )
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
--// FRAME & PANEL //----------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------

--// app icons (menubar & taskbar)
local app_icons = wx.wxIconBundle()
app_icons:AddIcon( wx.wxIcon( png_tbl[ 3 ], wx.wxBITMAP_TYPE_PNG, 16, 16 ) )
app_icons:AddIcon( wx.wxIcon( png_tbl[ 4 ], wx.wxBITMAP_TYPE_PNG, 32, 32 ) )

--// Hauptframe
frame = wx.wxFrame( wx.NULL, wx.wxID_ANY, app_name .. " " .. app_version, wx.wxPoint( 0, 0 ), wx.wxSize( app_width, app_height ), wx.wxMINIMIZE_BOX + wx.wxSYSTEM_MENU + wx.wxCAPTION + wx.wxCLOSE_BOX + wx.wxCLIP_CHILDREN )
frame:Centre( wx.wxBOTH )
frame:SetMenuBar( menu_bar )
frame:SetIcons( app_icons )
frame:CreateStatusBar( 2 )
frame:SetStatusWidths( { ( app_width / 100*80 ), ( app_width / 100*20 ) } )
frame:SetStatusText( app_name .. " bereit.", 0 )
frame:SetStatusText( "Timer: AUS", 1 )

--// main panel for frame
panel = wx.wxPanel( frame, wx.wxID_ANY, wx.wxPoint( 0, 0 ), wx.wxSize( app_width, app_height ) )

-------------------------------------------------------------------------------------------------------------------------------------
--// NOTEBOOK //---------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------

local notebook_image_list = wx.wxImageList( 16, 16 )

--// icon tab 1 - Profile
local bmp_user_16x16 = wx.wxBitmap():ConvertToImage(); bmp_user_16x16:LoadFile( png_tbl[ 5 ] )
local tab_1_img = notebook_image_list:Add( wx.wxBitmap( bmp_user_16x16 ) )

--// icon tab 2 - Telefonbuch
local bmp_phone_16x16 = wx.wxBitmap():ConvertToImage(); bmp_phone_16x16:LoadFile( png_tbl[ 6 ] )
local tab_2_img = notebook_image_list:Add( wx.wxBitmap( bmp_phone_16x16 ) )

--// icon tab 3 - Uhrzeiten
local bmp_clock_16x16 = wx.wxBitmap():ConvertToImage(); bmp_clock_16x16:LoadFile( png_tbl[ 7 ] )
local tab_3_img = notebook_image_list:Add( wx.wxBitmap( bmp_clock_16x16 ) )

--// icon tab 3 - Timer
local bmp_timer_16x16 = wx.wxBitmap():ConvertToImage(); bmp_timer_16x16:LoadFile( png_tbl[ 8 ] )
local tab_4_img = notebook_image_list:Add( wx.wxBitmap( bmp_timer_16x16 ) )

--// notebook
notebook = wx.wxNotebook( panel, wx.wxID_ANY, wx.wxPoint( 0, 10 ), wx.wxSize( notebook_width, notebook_height ) )
notebook:SetFont( default_font )
notebook:SetBackgroundColour( wx.wxColour( 225, 225, 225 ) )
notebook:SetImageList( notebook_image_list )

tab_1 = wx.wxPanel( notebook, wx.wxID_ANY )
notebook:AddPage( tab_1, "1. Profile" )
notebook:SetPageImage( 0, tab_1_img )

tab_2 = wx.wxPanel( notebook, wx.wxID_ANY )
notebook:AddPage( tab_2, "2. Telefonbuch" )
notebook:SetPageImage( 1, tab_2_img )

tab_3 = wx.wxPanel( notebook, wx.wxID_ANY )
notebook:AddPage( tab_3, "3. Uhrzeiten" )
notebook:SetPageImage( 2, tab_3_img )

tab_4 = wx.wxPanel( notebook, wx.wxID_ANY )
notebook:AddPage( tab_4, "4. Timer" )
notebook:SetPageImage( 3, tab_4_img )

-------------------------------------------------------------------------------------------------------------------------------------
--// TIMER & MEDIA //----------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------

--// timer
timer = nil
timer = wx.wxTimer( panel )

--// media
media_ctrl = wx.wxMediaCtrl( frame, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxSize( 0, 0 ) )

load_current_signaltone_selection( media_ctrl )

-------------------------------------------------------------------------------------------------------------------------------------
--// DIALOG WINDOWS //---------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------

--// alarm window
show_alert_window = function( t, book_name, book_number )
    local di_tim = wx.wxDialog(
        wx.NULL,
        wx.wxID_ANY,
        app_name .. " " .. app_version .. "   Achtung",
        wx.wxDefaultPosition,
        wx.wxSize( 600, 470 ),
        wx.wxSTAY_ON_TOP + wx.wxDEFAULT_DIALOG_STYLE - wx.wxCLOSE_BOX - wx.wxMAXIMIZE_BOX - wx.wxMINIMIZE_BOX
    )
    di_tim:SetMinSize( wx.wxSize( 600, 450 ) )
    di_tim:SetMaxSize( wx.wxSize( 600, 450 ) )
    di_tim:SetBackgroundColour( wx.wxColour( 255, 255, 0 ) )

    --// app logo
    local app_logo = wx.wxBitmap():ConvertToImage()
    app_logo:LoadFile( png_tbl[ 4 ] )

    control = wx.wxStaticBitmap( di_tim, wx.wxID_ANY, wx.wxBitmap( app_logo ), wx.wxPoint( 0, 20 ), wx.wxSize( app_logo:GetWidth(), app_logo:GetHeight() ) )
    control:Centre( wx.wxHORIZONTAL )
    app_logo:Destroy()

    --// app name / version
    control = wx.wxStaticText( di_tim, wx.wxID_ANY, app_name .. " " .. app_version, wx.wxPoint( 0, 65 ) )
    control:SetFont( about_bold )
    control:Centre( wx.wxHORIZONTAL )

    --// horizontal line
    control = wx.wxStaticLine( di_tim, wx.wxID_ANY, wx.wxPoint( 0, 105 ), wx.wxSize( 250, 2 ) )
    control:Centre( wx.wxHORIZONTAL )

    --// text - time
    control = wx.wxStaticText( di_tim, wx.wxID_ANY, "Es ist " .. t .. " Uhr", wx.wxPoint( 0, 125 ) )
    control:SetFont( timer_bold )
    control:Centre( wx.wxHORIZONTAL )

    --// horizontal line
    control = wx.wxStaticLine( di_tim, wx.wxID_ANY, wx.wxPoint( 0, 170 ), wx.wxSize( 400, 2 ) )
    control:Centre( wx.wxHORIZONTAL )

    --// text - book_name
    control = wx.wxStaticText( di_tim, wx.wxID_ANY, book_name, wx.wxPoint( 0, 193 ) )
    control:SetFont( timer_bold_2 )
    control:Centre( wx.wxHORIZONTAL )

    --// text - book_number
    control = wx.wxStaticText( di_tim, wx.wxID_ANY, book_number, wx.wxPoint( 0, 260 ) )
    control:SetFont( timer_bold_3 )
    control:Centre( wx.wxHORIZONTAL )

    --// button "OK"
    local btn_close = wx.wxButton( di_tim, wx.wxID_ANY, "OK", wx.wxPoint( 0, 360 ), wx.wxSize( 90, 60 ) )
    btn_close:SetBackgroundColour( wx.wxColour( 255, 255, 255 ) )
    btn_close:Centre( wx.wxHORIZONTAL )
    btn_close:SetFont( alarm_btn )
    btn_close:SetBackgroundColour( wx.wxColour( 0, 0, 0 ) )
    btn_close:SetForegroundColour( wx.wxColour( 255, 255, 0 ) )

    --// event - button "OK"
    btn_close:Connect( wx.wxID_ANY, wx.wxEVT_COMMAND_BUTTON_CLICKED,
    function( event )
        --// stop alarm tone
        media_control( media_ctrl, "stop" ) -- mode: "play" "pause" "stop"
        di_tim:Destroy()
    end )

    --// play alarm tone
    media_control( media_ctrl, "play" ) -- mode: "play" "pause" "stop"

    --// show dialog
    di_tim:ShowModal()
end

--// about window
show_about_window = function()
   local di_abo = wx.wxDialog(
        wx.NULL,
        wx.wxID_ANY,
        "Über" .. " " .. app_name,
        wx.wxDefaultPosition,
        wx.wxSize( 320, 395 ),
        wx.wxSTAY_ON_TOP + wx.wxDEFAULT_DIALOG_STYLE - wx.wxCLOSE_BOX - wx.wxMAXIMIZE_BOX - wx.wxMINIMIZE_BOX
    )
    di_abo:SetBackgroundColour( wx.wxColour( 255, 255, 255 ) )
    di_abo:SetMinSize( wx.wxSize( 320, 395 ) )
    di_abo:SetMaxSize( wx.wxSize( 320, 395 ) )

    --// app logo
    local app_logo = wx.wxBitmap():ConvertToImage()
    app_logo:LoadFile( png_tbl[ 4 ] )

    control = wx.wxStaticBitmap( di_abo, wx.wxID_ANY, wx.wxBitmap( app_logo ), wx.wxPoint( 0, 15 ), wx.wxSize( app_logo:GetWidth(), app_logo:GetHeight() ) )
    control:Centre( wx.wxHORIZONTAL )
    app_logo:Destroy()

    --// app name / version
    control = wx.wxStaticText( di_abo, wx.wxID_ANY, app_name .. " " .. app_version, wx.wxPoint( 0, 60 ) )
    control:SetFont( about_bold )
    control:Centre( wx.wxHORIZONTAL )

    --// app copyright
    control = wx.wxStaticText( di_abo, wx.wxID_ANY, app_copyright, wx.wxPoint( 0, 90 ) )
    control:SetFont( about_normal_2 )
    control:Centre( wx.wxHORIZONTAL )

    --// environment
    control = wx.wxStaticText( di_abo, wx.wxID_ANY, app_env, wx.wxPoint( 0, 122 ) )
    control:SetFont( about_normal_2 )
    control:Centre( wx.wxHORIZONTAL )

    --// build with
    control = wx.wxStaticText( di_abo, wx.wxID_ANY, app_build, wx.wxPoint( 0, 137 ) )
    control:SetFont( about_normal_2 )
    control:Centre( wx.wxHORIZONTAL )

    --// horizontal line
    control = wx.wxStaticLine( di_abo, wx.wxID_ANY, wx.wxPoint( 0, 168 ), wx.wxSize( 275, 1 ) )
    control:Centre( wx.wxHORIZONTAL )

    --// license
    control = wx.wxStaticText( di_abo, wx.wxID_ANY, app_license, wx.wxPoint( 0, 180 ) )
    control:SetFont( about_normal_2 )
    control:Centre( wx.wxHORIZONTAL )

    --// GPL logo
    local gpl_logo = wx.wxBitmap():ConvertToImage()
    gpl_logo:LoadFile( png_tbl[ 1 ] )

    control = wx.wxStaticBitmap( di_abo, wx.wxID_ANY, wx.wxBitmap( gpl_logo ), wx.wxPoint( 20, 220 ), wx.wxSize( gpl_logo:GetWidth(), gpl_logo:GetHeight() ) )
    gpl_logo:Destroy()

    --// OSI Logo
    local osi_logo = wx.wxBitmap():ConvertToImage()
    osi_logo:LoadFile( png_tbl[ 2 ] )

    control = wx.wxStaticBitmap( di_abo, wx.wxID_ANY, wx.wxBitmap( osi_logo ), wx.wxPoint( 200, 210 ), wx.wxSize( osi_logo:GetWidth(), osi_logo:GetHeight() ) )
    osi_logo:Destroy()

    --// button "Schließen"
    local about_btn_close = wx.wxButton( di_abo, wx.wxID_ANY, "Schließen", wx.wxPoint( 0, 335 ), wx.wxSize( 80, 20 ) )
    about_btn_close:SetBackgroundColour( wx.wxColour( 255, 255, 255 ) )
    about_btn_close:Centre( wx.wxHORIZONTAL )

    --// event - button "Schließen"
    about_btn_close:Connect( wx.wxID_ANY, wx.wxEVT_COMMAND_BUTTON_CLICKED,
    function( event )
        di_abo:Destroy()
    end )

    --// show dialog
    di_abo:ShowModal()
end

--// settings window
show_settings_window = function()
    local di_set = wx.wxDialog(
        wx.NULL,
        wx.wxID_ANY,
        "Einstellungen",
        wx.wxDefaultPosition,
        wx.wxSize( 155, 340 ),
        wx.wxSTAY_ON_TOP + wx.wxDEFAULT_DIALOG_STYLE - wx.wxCLOSE_BOX - wx.wxMAXIMIZE_BOX - wx.wxMINIMIZE_BOX
    )
    di_set:SetBackgroundColour( wx.wxColour( 255, 255, 255 ) )
    di_set:SetMinSize( wx.wxSize( 155, 340 ) )
    di_set:SetMaxSize( wx.wxSize( 155, 340 ) )

	--// alarmtone radiobox
	local alarm_radio = wx.wxRadioBox(
        di_set,
        wx.wxID_ANY,
        "Signalton",
        wx.wxPoint( 10, 10 ),
        wx.wxSize( 127, 200 ),
        sorted_array_audio( audio_tbl ),
        1,
        wx.wxSUNKEN_BORDER
    )
    local current_radio_choice = cfg_tbl[ "signaltone" ] - 1
    alarm_radio:SetSelection( current_radio_choice )
    local current_radio_choice_file = audio_tbl[ current_radio_choice + 1 ][ 1 ]
    media_ctrl:Load( current_radio_choice_file )

	--// event - alarmtone radiobox
	alarm_radio:Connect( wx.wxID_ANY, wx.wxEVT_COMMAND_RADIOBOX_SELECTED,
	function( event )
        local choice = alarm_radio:GetSelection() + 1
        local file = audio_tbl[ choice ][ 1 ]
        media_ctrl:Load( file )
	end )

    --// border
    control = wx.wxStaticBox( di_set, wx.wxID_ANY, "Lautstärke", wx.wxPoint( 10, 220 ), wx.wxSize( 127, 45 ) )

    --// volumebar slider
    local volume_slider = wx.wxSlider(
        di_set,
        wx.wxID_ANY,
        slider_range,
        0,
        slider_range,
        wx.wxPoint( 15, 235 ),
        wx.wxSize( 117, 25 ),
        wx.wxSL_HORIZONTAL
    )
    local current_volume = cfg_tbl[ "volume" ]
    volume_slider:SetValue( current_volume * slider_range )

    --// event - volume_slider
    volume_slider:Connect( wx.wxID_ANY, wx.wxEVT_SCROLL_THUMBRELEASE,
    function( event )
        local pos = event:GetPosition()
        media_ctrl:SetVolume( pos / slider_range )
    end )

    --// button "Test"
    local settings_btn_test = wx.wxButton( di_set, wx.wxID_ANY, "Test", wx.wxPoint( 12, 280 ), wx.wxSize( 60, 20 ) )
    settings_btn_test:SetBackgroundColour( wx.wxColour( 255, 255, 255 ) )

    --// event - button "Test"
    settings_btn_test:Connect( wx.wxID_ANY, wx.wxEVT_COMMAND_BUTTON_CLICKED,
    function( event )
        media_control( media_ctrl, "play" ) -- mode: "play" "pause" "stop"
    end )

    --// button "OK"
    local settings_btn_ok = wx.wxButton( di_set, wx.wxID_ANY, "OK", wx.wxPoint( 75, 280 ), wx.wxSize( 60, 20 ) )
    settings_btn_ok:SetBackgroundColour( wx.wxColour( 255, 255, 255 ) )

    --// event - button "OK"
    settings_btn_ok:Connect( wx.wxID_ANY, wx.wxEVT_COMMAND_BUTTON_CLICKED,
    function( event )
        local choice = alarm_radio:GetSelection() + 1
        local volume = media_ctrl:GetVolume()
        cfg_tbl[ "signaltone" ] = choice
        cfg_tbl[ "volume" ] = volume
        save( true, false, false, false ) -- config, user, phonebook, timer
        frame:SetStatusText( "Neuer Signalton: " .. audio_tbl[ choice ][ 2 ], 0 )
        media_control( media_ctrl, "stop" ) -- mode: "play" "pause" "stop"
        di_set:Destroy()
    end )

    di_set:ShowModal()
end

--// tutorial windows
show_tutorial_window = function()
    local di_tut = wx.wxDialog(
        wx.NULL,
        wx.wxID_ANY,
        "Anleitung",
        wx.wxDefaultPosition,
        wx.wxSize( 450, 425 ),
        wx.wxSTAY_ON_TOP + wx.wxDEFAULT_DIALOG_STYLE - wx.wxCLOSE_BOX - wx.wxMAXIMIZE_BOX - wx.wxMINIMIZE_BOX
    )
    di_tut:SetBackgroundColour( wx.wxColour( 255, 255, 255 ) )
    di_tut:SetMinSize( wx.wxSize( 450, 425 ) )
    di_tut:SetMaxSize( wx.wxSize( 450, 425 ) )

    --// app logo
    local app_logo = wx.wxBitmap():ConvertToImage()
    app_logo:LoadFile( png_tbl[ 4 ] )

    control = wx.wxStaticBitmap( di_tut, wx.wxID_ANY, wx.wxBitmap( app_logo ), wx.wxPoint( 0, 15 ), wx.wxSize( app_logo:GetWidth(), app_logo:GetHeight() ) )
    control:Centre( wx.wxHORIZONTAL )
    app_logo:Destroy()

    --// app name / version
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
    control:SetFont( default_font )
    control:SetBackgroundColour( wx.wxBLACK )
    control:SetForegroundColour( wx.wxColour( 255, 255, 255 ) )
    control:Centre( wx.wxHORIZONTAL )

    --// button "Schließen"
    local settings_btn_close = wx.wxButton( di_tut, wx.wxID_ANY, "Schließen", wx.wxPoint( 0, 365 ), wx.wxSize( 80, 20 ) )
    settings_btn_close:SetBackgroundColour( wx.wxColour( 255, 255, 255 ) )
    settings_btn_close:Centre( wx.wxHORIZONTAL )

    --// event - button "Schließen"
    settings_btn_close:Connect( wx.wxID_ANY, wx.wxEVT_COMMAND_BUTTON_CLICKED,
    function( event )
        di_tut:Destroy()
    end )

    --// show dialog
    di_tut:ShowModal()
end

-------------------------------------------------------------------------------------------------------------------------------------
--// Tab 1 //------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------

--// border
control = wx.wxStaticBox( tab_1, wx.wxID_ANY, "Profil  erstellen / löschen", wx.wxPoint( 20, 10 ), wx.wxSize( 350, 337 ) )

--// statictext
control = wx.wxStaticText( tab_1, wx.wxID_ANY, "Benutzername bzw. Objektname:", wx.wxPoint( 35, 36 ) )

--// newuser_textctrl
newuser_textctrl = wx.wxTextCtrl( tab_1, wx.wxID_ANY, "", wx.wxPoint( 35, 52 ), wx.wxSize( 320, 20 ), wx.wxTE_PROCESS_ENTER + wx.wxTE_CENTRE )
newuser_textctrl:SetBackgroundColour( wx.wxColour( 255, 255, 255 ) )

--// database - add user
add_user = function( newuser_textctrl, user_listbox )
    local tUser = newuser_textctrl:GetValue()
    local check, err = check_user( tUser )
    if check then
        -- add user
        user_tbl[ tUser ] = true
        save( false, true, false, false ) -- config, user, phonebook, timer
        -- tab 1 changes
        newuser_textctrl:SetValue( "" )
        user_listbox:Set( sorted_array_user( user_tbl ) )
        user_listbox:SetSelection( 0 )
        -- tab 3 changes
        user_choice:Clear()
        user_choice:Append( sorted_array_user( user_tbl ) )
        time_listbox:Set( sorted_array_time( timer_tbl, user ) )
        time_listbox:SetSelection( 0 )
        -- tab 4 changes
        status_textctrl:SetForegroundColour( wx.wxColour( 255, 0, 0 ) )
        status_textctrl:SetValue( ">  D E A K T I V I E R T  <" )
        timer_current_profile:SetValue( "" )
        timer_next_time:SetValue( "" )
        timer_remaining_time:SetValue( "" )
        timer_gauge:SetValue( 0 )
        timer_start_button:Enable( true )
        timer_stop_button:Disable()
        -- timer
        set_timer( false, true ) -- mode: timer on/off (bool); dialog: send dialog if timer is off (bool)
        -- dialog
        di = wx.wxMessageDialog( frame, "Profil hinzugefügt: " .. tUser, "Hinweis", wx.wxOK )
        di:ShowModal(); di:Destroy()
    else
        -- dialog
        di = wx.wxMessageDialog( frame, "Fehler: Keine gültige Eingabe." .. "\n\n" .. err, "Hinweis", wx.wxOK )
        di:ShowModal(); di:Destroy()
    end
end

--// database - delete user
del_user = function( newuser_textctrl, user_listbox )
    if user_listbox:GetSelection() == -1 then
        -- dialog
        di = wx.wxMessageDialog( frame, "Fehler: Kein Benutzer ausgewählt.", "Hinweis", wx.wxOK )
        di:ShowModal(); di:Destroy()
    else
        local tUser = user_listbox:GetString( user_listbox:GetSelection() )
        if tUser then
            -- del user
            user_tbl[ tUser ] = nil
            timer_tbl[ tUser ] = nil
            save( false, true, false, false ) -- config, user, phonebook, timer
            save( false, false, false, true ) -- config, user, phonebook, timer
            -- tab 1 changes
            newuser_textctrl:SetValue( "" )
            user_listbox:Set( sorted_array_user( user_tbl ) )
            user_listbox:SetSelection( 0 )
            -- tab 3 changes
            user_choice:Clear()
            user_choice:Append( sorted_array_user( user_tbl ) )
            time_listbox:Set( sorted_array_time( timer_tbl, user ) )
            time_listbox:SetSelection( 0 )
            -- tab 4 changes
            status_textctrl:SetForegroundColour( wx.wxColour( 255, 0, 0 ) )
            status_textctrl:SetValue( ">  D E A K T I V I E R T  <" )
            timer_current_profile:SetValue( "" )
            timer_next_time:SetValue( "" )
            timer_remaining_time:SetValue( "" )
            timer_gauge:SetValue( 0 )
            timer_start_button:Enable( true )
            timer_stop_button:Disable()
            -- timer
            set_timer( false, true ) -- mode: timer on/off (bool); dialog: send dialog if timer is off (bool)
            -- dialog
            di = wx.wxMessageDialog( frame, "Benutzer gelöscht: " .. tUser, "Hinweis", wx.wxOK )
            di:ShowModal(); di:Destroy()
        else
            -- dialog
            di = wx.wxMessageDialog( frame, "Benutzer nicht gefunden: " .. tUser, "Hinweis", wx.wxOK )
            di:ShowModal(); di:Destroy()
        end
    end
end

--// staticbox
control = wx.wxStaticBox( tab_1, wx.wxID_ANY, "", wx.wxPoint( 35, 78 ), wx.wxSize( 320, 235 ) )

--// user_listbox
user_listbox = wx.wxListBox( tab_1, wx.wxID_ANY, wx.wxPoint( 45, 93 ), wx.wxSize( 300, 212 ), sorted_array_user( user_tbl ), wx.wxLB_SINGLE + wx.wxLB_HSCROLL + wx.wxLB_SORT )
user_listbox:SetSelection( 0 ) -- ersten Eintrag markieren

--// button "hinzufügen"
user_add_button = wx.wxButton( tab_1, wx.wxID_ANY, "Hinzufügen", wx.wxPoint( 35, 314 ), wx.wxSize( 155, 21 ) )
user_add_button:Connect( wx.wxID_ANY, wx.wxEVT_COMMAND_BUTTON_CLICKED,
function( event )
    add_user( newuser_textctrl, user_listbox )
end )
user_add_button:Disable()

--// button "löschen"
user_del_button = wx.wxButton( tab_1, wx.wxID_ANY, "Löschen", wx.wxPoint( 200, 314 ), wx.wxSize( 155, 21 ) )
user_del_button:Connect( wx.wxID_ANY, wx.wxEVT_COMMAND_BUTTON_CLICKED,
function( event )
    del_user( newuser_textctrl, user_listbox )
end )

--// event - newuser_textctrl
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

--// database - add phonebook entry
add_book = function( newbook_name_textctrl, newbook_number_textctrl, book_listbox, book_add_button )
    local tBook_name = newbook_name_textctrl:GetValue()
    local tBook_number = newbook_number_textctrl:GetValue()
    local check_name, check_number, err = check_book( tBook_name, tBook_number )
    if check_name and check_number then
        -- add phonebook entry
        book_tbl[ tBook_name ] = tBook_number
        save( false, false, true, false ) -- config, user, phonebook, timer
        -- tab 2 changes
        newbook_name_textctrl:SetValue( "" )
        newbook_number_textctrl:SetValue( "" )
        book_listbox:Set( sorted_array_book( book_tbl ) )
        book_listbox:SetSelection( 0 )
        book_add_button:Disable()
        -- dialog
        di = wx.wxMessageDialog( frame, "Eintrag hinzugefügt:\n\nName:\t" .. tBook_name .. "\nNummer:\t" .. tBook_number, "Hinweis", wx.wxOK )
        di:ShowModal(); di:Destroy()
    else
        -- dialog
        di = wx.wxMessageDialog( frame, "Fehler: Keine gültige Eingabe." .. "\n\n" .. err, "Hinweis", wx.wxOK )
        di:ShowModal(); di:Destroy()
    end
end

--// database - delete phonebook entry
del_book = function( newbook_name_textctrl, newbook_number_textctrl, book_listbox )
    if book_listbox:GetSelection() == -1 then
        -- dialog
        di = wx.wxMessageDialog( frame, "Fehler: Kein Eintrag ausgewählt.", "Hinweis", wx.wxOK )
        di:ShowModal(); di:Destroy()
    else
        local tBook = book_listbox:GetString( book_listbox:GetSelection() )
        if tBook then
            -- del phonebook entry
            local n, _ = string.find( tBook, "Nummer:" ); n = n - 4
            local s = string.sub( tBook, 7, n )
            book_tbl[ s ] = nil
            save( false, false, true, false ) -- config, user, phonebook, timer
            -- tab 2 changes
            newbook_name_textctrl:SetValue( "" )
            newbook_number_textctrl:SetValue( "" )
            book_listbox:Set( sorted_array_book( book_tbl ) )
            book_listbox:SetSelection( 0 )
            -- dialog
            di = wx.wxMessageDialog( frame, "Eintrag gelöscht: " .. tBook, "Hinweis", wx.wxOK )
            di:ShowModal(); di:Destroy()
        end
    end
end

--// border
control = wx.wxStaticBox( tab_2, wx.wxID_ANY, "Neuer Telefonbucheintrag", wx.wxPoint( 20, 10 ), wx.wxSize( 350, 337 ) )

--// statictext - name
control = wx.wxStaticText( tab_2, wx.wxID_ANY, "NSC Name:", wx.wxPoint( 35, 36 ) )

--// newbook_name_textctrl
newbook_name_textctrl = wx.wxTextCtrl( tab_2, wx.wxID_ANY, "", wx.wxPoint( 35, 52 ), wx.wxSize( 320, 20 ), wx.wxTE_PROCESS_ENTER + wx.wxTE_CENTRE )
newbook_name_textctrl:SetBackgroundColour( wx.wxColour( 255, 255, 255 ) )

--// statictext - number
control = wx.wxStaticText( tab_2, wx.wxID_ANY, "NSC Nummer:", wx.wxPoint( 35, 76 ) )

--// newbook_number_textctrl
newbook_number_textctrl = wx.wxTextCtrl( tab_2, wx.wxID_ANY, "", wx.wxPoint( 35, 92 ), wx.wxSize( 320, 20 ), wx.wxTE_PROCESS_ENTER + wx.wxTE_CENTRE )
newbook_number_textctrl:SetBackgroundColour( wx.wxColour( 255, 255, 255 ) )

--// border
control = wx.wxStaticBox( tab_2, wx.wxID_ANY, "", wx.wxPoint( 35, 118 ), wx.wxSize( 320, 195 ) )

--// book_listbox
book_listbox = wx.wxListBox( tab_2, wx.wxID_ANY, wx.wxPoint( 45, 133 ), wx.wxSize( 300, 172 ), sorted_array_book( book_tbl ), wx.wxLB_SINGLE + wx.wxLB_HSCROLL + wx.wxLB_SORT )
book_listbox:SetSelection( 0 ) -- ersten Eintrag markieren

--// button "hinzufügen"
book_add_button = wx.wxButton( tab_2, wx.wxID_ANY, "Hinzufügen", wx.wxPoint( 35, 314 ), wx.wxSize( 155, 21 ) )
book_add_button:Disable()

--// button "löschen"
book_del_button = wx.wxButton( tab_2, wx.wxID_ANY, "Löschen", wx.wxPoint( 200, 314 ), wx.wxSize( 155, 21 ) )

--// event - button "hinzufügen"
book_add_button:Connect( wx.wxID_ANY, wx.wxEVT_COMMAND_BUTTON_CLICKED,
function( event )
    add_book( newbook_name_textctrl, newbook_number_textctrl, book_listbox, book_add_button )
end )

--// event - button "löschen"
book_del_button:Connect( wx.wxID_ANY, wx.wxEVT_COMMAND_BUTTON_CLICKED,
function( event )
    del_book( newbook_name_textctrl, newbook_number_textctrl, book_listbox )
end )

--// event - newbook_name_textctrl
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

--// event - newbook_number_textctrl
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

--// border
control = wx.wxStaticBox( tab_3, wx.wxID_ANY, "Profil auswählen:", wx.wxPoint( 20, 10 ), wx.wxSize( 350, 55 ) )

--// user_choice
user_choice = wx.wxChoice(
    tab_3,
    wx.wxID_ANY,
    wx.wxPoint( 35, 30 ),
    wx.wxSize( 320, 20 ),
    sorted_array_user( user_tbl )
)
user_choice:Select( -1 )

--// border
control = wx.wxStaticBox( tab_3, wx.wxID_ANY, "Uhrzeiten  eintragen / löschen", wx.wxPoint( 20, 80 ), wx.wxSize( 350, 267 ) )

--// statictext
control = wx.wxStaticText( tab_3, wx.wxID_ANY, "Schema: hh:mm", wx.wxPoint( 35, 101 ) )

--// newtime_textctrl
newtime_textctrl = wx.wxTextCtrl( tab_3, wx.wxID_ANY, "", wx.wxPoint( 35, 117 ), wx.wxSize( 320, 20 ), wx.wxTE_PROCESS_ENTER + wx.wxTE_CENTRE )
newtime_textctrl:SetBackgroundColour( wx.wxColour( 255, 255, 255 ) )

--// event - newtime_textctrl
newtime_textctrl:Connect( wx.wxID_ANY, wx.wxEVT_KILL_FOCUS,
function( event )
    local s = newtime_textctrl:GetValue()
    local new, n = string.gsub( s, " ", "" )
    if n ~= 0 then
        -- dialog
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

--// border
control = wx.wxStaticBox( tab_3, wx.wxID_ANY, "", wx.wxPoint( 35, 143 ), wx.wxSize( 320, 170 ) )

--// time_listbox
time_listbox = wx.wxListBox( tab_3, wx.wxID_ANY, wx.wxPoint( 45, 158 ), wx.wxSize( 300, 147 ), sorted_array_time( timer_tbl ), wx.wxLB_SINGLE + wx.wxLB_HSCROLL + wx.wxLB_SORT + wx.wxSUNKEN_BORDER )
time_listbox:SetSelection( 0 ) -- markup first entry
time_listbox:SetFont( timer_list )

--// button "hinzufügen"
time_add_button = wx.wxButton( tab_3, wx.wxID_ANY, "Hinzufügen", wx.wxPoint( 35, 314 ), wx.wxSize( 155, 21 ) )
time_add_button:Disable()

--// button "löschen"
time_del_button = wx.wxButton( tab_3, wx.wxID_ANY, "Löschen", wx.wxPoint( 200, 314 ), wx.wxSize( 155, 21 ) )

--// database - add new time
add_time = function( user, newtime_textctrl, time_listbox, book_name, book_number )
    local tTime = newtime_textctrl:GetValue()
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
            -- tab 3 changes
            newtime_textctrl:SetValue( "" )
            time_listbox:Set( sorted_array_time( timer_tbl, user ) )
            time_listbox:SetSelection( 0 )
            user_choice:Update( sorted_array_user( user_tbl ) )
            time_add_button:Disable()
            -- tab 4 changes
            status_textctrl:SetForegroundColour( wx.wxColour( 255, 0, 0 ) )
            status_textctrl:SetValue( ">  D E A K T I V I E R T  <" )
            timer_current_profile:SetValue( "" )
            timer_next_time:SetValue( "" )
            timer_remaining_time:SetValue( "" )
            timer_gauge:SetValue( 0 )
            timer_start_button:Enable( true )
            timer_stop_button:Disable()
            -- timer
            set_timer( false, true ) -- mode: timer on/off (bool); dialog: send dialog if timer is off (bool)
            -- dialog
            di = wx.wxMessageDialog( frame, "Profil:\t\t" .. user .. "\nUhrzeit:\t\t" .. tTime .. "\n\nNSC Name:\t" .. book_name .. "\nNSC Nummer:\t" .. book_number, "Hinweis", wx.wxOK )
            di:ShowModal(); di:Destroy()
        end
    else
        -- tab 3 changes
        newtime_textctrl:SetValue( "" )
        time_add_button:Disable()
        -- dialog
        di = wx.wxMessageDialog( frame, "Fehler: Keine gültige Eingabe." .. "\n\n" .. err, "Hinweis", wx.wxOK )
        di:ShowModal(); di:Destroy()
    end
end

--// database - delete time
del_time = function( user, newtime_textctrl, time_listbox )
    if time_listbox:GetSelection() == -1 then
        -- dialog
        di = wx.wxMessageDialog( frame, "Fehler: Keine Uhrzeit ausgewählt.", "Hinweis", wx.wxOK )
        di:ShowModal(); di:Destroy()
    else
        -- del time
        local user = user_choice:GetStringSelection()
        local tTime = time_listbox:GetString( time_listbox:GetSelection() )
        if tTime then timer_tbl[ user ][ tTime ] = nil end
        save( false, false, false, true ) -- config, user, phonebook, timer
        -- tab 3 changes
        newtime_textctrl:SetValue( "" )
        time_listbox:Set( sorted_array_time( timer_tbl, user ) )
        time_listbox:SetSelection( 0 )
        -- tab 4 changes
        status_textctrl:SetForegroundColour( wx.wxColour( 255, 0, 0 ) )
        status_textctrl:SetValue( ">  D E A K T I V I E R T  <" )
        timer_current_profile:SetValue( "" )
        timer_next_time:SetValue( "" )
        timer_remaining_time:SetValue( "" )
        timer_gauge:SetValue( 0 )
        timer_start_button:Enable( true )
        timer_stop_button:Disable()
        -- timer
        set_timer( false, true ) -- mode: timer on/off (bool); dialog: send dialog if timer is off (bool)
        -- dialog
        di = wx.wxMessageDialog( frame, "Uhrzeit gelöscht: " .. tTime, "Hinweis", wx.wxOK )
        di:ShowModal(); di:Destroy()
    end
end

--// event - time_add_button
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
        -- dialog
        di = wx.wxDialog( frame, wx.wxID_ANY, "NSC Leitstelle auswählen:", wx.wxDefaultPosition, wx.wxSize( 245, 100 ), wx.wxSTAY_ON_TOP + wx.wxDEFAULT_DIALOG_STYLE - wx.wxCLOSE_BOX - wx.wxMAXIMIZE_BOX - wx.wxMINIMIZE_BOX )
        di:SetBackgroundColour( wx.wxColour( 255, 255, 255 ) )
        di:SetMinSize( wx.wxSize( 245, 100 ) )
        di:SetMaxSize( wx.wxSize( 245, 100 ) )
        --// book_choice
        local book_choice = wx.wxChoice(
            di,
            wx.wxID_ANY,
            wx.wxPoint( 10, 10 ),
            wx.wxSize( 218, 20 ),
            sorted_array_user( book_tbl )
        )
        book_choice:Select( 0 )
        --// button "OK"
        local btn_close = wx.wxButton( di, wx.wxID_ANY, "OK", wx.wxPoint( 0, 42 ), wx.wxSize( 80, 20 ) )
        btn_close:SetBackgroundColour( wx.wxColour( 255, 255, 255 ) )
        btn_close:Centre( wx.wxHORIZONTAL )
        --// event - btn_close
        btn_close:Connect( wx.wxID_ANY, wx.wxEVT_COMMAND_BUTTON_CLICKED,
        function( event )
            local entry = book_choice:GetStringSelection()
            for k, v in pairs( book_tbl ) do
                if k == entry then book_name = k; book_number = v; break end
            end
            di:Destroy()
        end )
        di:ShowModal()
        -- add time
        add_time( user, newtime_textctrl, time_listbox, book_name, book_number )
    end
end )

--// event - time_del_button
time_del_button:Connect( wx.wxID_ANY, wx.wxEVT_COMMAND_BUTTON_CLICKED,
function( event )
    local user = user_choice:GetStringSelection()
    del_time( user, newtime_textctrl, time_listbox )
    set_timer( false, true ) -- mode: timer on/off (bool); dialog: send dialog if timer is off (bool)
end )

--// event - user_choice
user_choice:Connect( wx.wxID_ANY, wx.wxEVT_COMMAND_CHOICE_SELECTED,
function( event )
    if newtime_textctrl:GetValue() ~= "" then
        time_add_button:Enable( true )
    end
    local user = user_choice:GetStringSelection()
    time_listbox:Set( sorted_array_time( timer_tbl, user ) )
    set_timer( false, true ) -- mode: timer on/off (bool); dialog: send dialog if timer is off (bool)
end )

--// event - newtime_textctrl
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

--// border
control = wx.wxStaticBox( tab_4, wx.wxID_ANY, "Timer Status", wx.wxPoint( 50, 15 ), wx.wxSize( 290, 309 ) )

--// status_textctrl
status_textctrl = wx.wxTextCtrl( tab_4, wx.wxID_ANY, "", wx.wxPoint( 62, 35 ), wx.wxSize( 266, 28 ), wx.wxTE_READONLY + wx.wxTE_CENTRE )-- + wx.wxNO_BORDER )
status_textctrl:SetBackgroundColour( wx.wxColour( 40, 40, 40 ) )
status_textctrl:SetFont( timer_status )
status_textctrl:SetForegroundColour( wx.wxColour( 255, 0, 0 ) )
status_textctrl:SetValue( ">  D E A K T I V I E R T  <" )

--// button - Timer start
timer_start_button = wx.wxButton( tab_4, wx.wxID_ANY, "START", wx.wxPoint( 62, 73 ), wx.wxSize( 130, 98 ) )
timer_start_button:SetBackgroundColour( wx.wxColour( 180, 180, 180 ) )
timer_start_button:SetFont( timer_btn )

--// button - Timer stop
timer_stop_button = wx.wxButton( tab_4, wx.wxID_ANY, "STOP", wx.wxPoint( 197, 73 ), wx.wxSize( 130, 98 ) )
timer_stop_button:SetBackgroundColour( wx.wxColour( 180, 180, 180 ) )
timer_stop_button:SetFont( timer_btn )
timer_stop_button:Disable()

--// text
control = wx.wxStaticText( tab_4, wx.wxID_ANY, "Ausgewähltes Profil", wx.wxPoint( 65, 193 ) )

--// timer_current_profile
timer_current_profile = wx.wxTextCtrl( tab_4, wx.wxID_ANY, "", wx.wxPoint( 62, 207 ), wx.wxSize( 266, 22 ), wx.wxTE_READONLY + wx.wxTE_CENTRE + wx.wxSUNKEN_BORDER )
timer_current_profile:SetFont( timer_choice )
timer_current_profile:SetBackgroundColour( wx.wxColour( 210, 210, 210 ) )

--// text
control = wx.wxStaticText( tab_4, wx.wxID_ANY, "Nächste Uhrzeit", wx.wxPoint( 65, 233 ) )

--// timer_next_time
timer_next_time = wx.wxTextCtrl( tab_4, wx.wxID_ANY, "", wx.wxPoint( 62, 247 ), wx.wxSize( 266, 22 ), wx.wxTE_READONLY + wx.wxTE_CENTRE + wx.wxSUNKEN_BORDER )
timer_next_time:SetFont( timer_choice )
timer_next_time:SetBackgroundColour( wx.wxColour( 210, 210, 210 ) )

--// text
control = wx.wxStaticText( tab_4, wx.wxID_ANY, "Verbleibende Zeit", wx.wxPoint( 65, 273 ) )

--// timer_remaining_time
timer_remaining_time = wx.wxTextCtrl( tab_4, wx.wxID_ANY, "", wx.wxPoint( 62, 287 ), wx.wxSize( 266, 22 ), wx.wxTE_READONLY + wx.wxTE_CENTRE + wx.wxSUNKEN_BORDER )
timer_remaining_time:SetFont( timer_choice )
timer_remaining_time:SetBackgroundColour( wx.wxColour( 210, 210, 210 ) )

--// timer_gauge
timer_gauge = wx.wxGauge( tab_4, wx.wxID_ANY, gauge_max_range, wx.wxPoint( 63, 307 ), wx.wxSize( 264, 5 ), wx.wxGA_HORIZONTAL + wx.wxGA_SMOOTH )

--// event - timer_start_button
timer_start_button:Connect( wx.wxID_ANY, wx.wxEVT_COMMAND_BUTTON_CLICKED,
function( event )
    local choice = tonumber( user_choice:GetCurrentSelection() )
    local user = user_choice:GetStringSelection()
    local time_next, time_remaining, seconds = get_next_time( timer_tbl, user )
    gauge_seconds = 0
    local any_time_exists = false
    if choice == -1 then
        -- dialog
        di = wx.wxMessageDialog( frame, "Kein Profil in Tab 3 (Uhrzeiten) ausgewählt.", "Hinweis", wx.wxOK )
        di:ShowModal(); di:Destroy()
    else
        for k, v in pairs( timer_tbl ) do
            if ( k == user ) and ( not tbl_is_empty( v ) ) then
                any_time_exists = true
                break
            end
        end
        if any_time_exists then
            -- tab 4 changes
            timer_start_button:Disable()
            timer_stop_button:Enable( true )
            status_textctrl:SetForegroundColour( wx.wxColour( 80, 240, 114 ) )
            status_textctrl:SetValue( ">     A K T I V I E R T     <" )
            timer_current_profile:SetValue( user )
            timer_gauge:SetRange( seconds )
            timer_gauge:SetValue( gauge_seconds )
            -- timer
            set_timer( true, false ) -- mode: timer on/off (bool); dialog: send dialog if timer is off (bool)
        else
            -- dialog
            di = wx.wxMessageDialog( frame, "Das Profil in Tab 3 (Uhrzeiten) enthält keine Zeiten.", "Hinweis", wx.wxOK )
            di:ShowModal(); di:Destroy()
        end
    end
end )

--// event - timer_stop_button
timer_stop_button:Connect( wx.wxID_ANY, wx.wxEVT_COMMAND_BUTTON_CLICKED,
function( event )
    -- tab 4 changes
    timer_start_button:Enable( true )
    timer_stop_button:Disable()
    status_textctrl:SetForegroundColour( wx.wxColour( 255, 0, 0 ) )
    status_textctrl:SetValue( ">  D E A K T I V I E R T  <" )
    timer_current_profile:SetValue( "" )
    timer_next_time:SetValue( "" )
    timer_remaining_time:SetValue( "" )
    timer_gauge:SetValue( 0 )
    -- timer
    set_timer( false, false ) -- mode: timer on/off (bool); dialog: send dialog if timer is off (bool)
end )

--// blinking eye catcher
local show_status_text = false
status_blink = function( status_textctrl )
    if show_status_text then
        status_textctrl:SetValue( ">     A K T I V I E R T     <" )
        show_status_text = false
    else
        status_textctrl:SetValue( "" )
        show_status_text = true
    end
end

--[[
--// DEBUG - button - test alarm window
timer_test_alert = wx.wxButton( tab_4, wx.wxID_ANY, "TEST", wx.wxPoint( 5, 340 ), wx.wxSize( 50, 20 ) )
timer_test_alert:SetBackgroundColour( wx.wxColour( 255, 255, 0 ) )
timer_test_alert:Connect( wx.wxID_ANY, wx.wxEVT_COMMAND_BUTTON_CLICKED,
function( event ) show_alert_window( "18:00", "MAN Diesel", "0821 - 11 22 33 44 55"  ) end )
]]

-------------------------------------------------------------------------------------------------------------------------------------
--// MAIN LOOP //--------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------

--// event - timer
panel:Connect( wx.wxEVT_TIMER, -- timer iteration
function( event )
    local t = os.date( "%H:%M" )
    local user = user_choice:GetStringSelection()
    local book_name, book_number = get_current_time_infos( t, user )
    local time_next, time_remaining, seconds = get_next_time( timer_tbl, user )
    if book_name then
        show_alert_window( t, book_name, book_number )
        gauge_seconds = 0
        timer_gauge:SetRange( seconds )
    end
    status_blink( status_textctrl )
    timer_next_time:SetValue( time_next )
    timer_remaining_time:SetValue( time_remaining )
    timer_gauge:SetValue( gauge_seconds )
    gauge_seconds = gauge_seconds + 1
end )

main = function()
    if exec then
        -- execute frame
        frame:Show( true )
        frame:Connect( wx.wxEVT_CLOSE_WINDOW,
        function( event )
            di = wx.wxMessageDialog( frame, "Wirklich beenden?", "Hinweis", wx.wxYES_NO + wx.wxICON_QUESTION + wx.wxCENTRE )
            result = di:ShowModal(); di:Destroy()
            if result == wx.wxID_YES then
                if event then event:Skip() end
                if timer then timer:Stop(); timer:delete(); timer = nil end
                if frame then frame:Destroy() end
            end
        end )
        -- events - menubar
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
    else
        -- kill frame
        if event then event:Skip() end
        if timer then timer:Stop(); timer:delete(); timer = nil end
        if frame then frame:Destroy() end
    end
end

main()
wx.wxGetApp():MainLoop()