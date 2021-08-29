--[[

    NSC Tool

        Author:       Benjamin Kupka
        License:      GNU GPLv3
        Environment:  wxLua-2.8.12.3-Lua-5.1.5-MSW-Unicode

        Beschreibung:

            Das Tool erinnert akustisch an die notwendigen Telefonate an die zuständige Serviceleitstelle.


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
local app_version      = "v0.6"
local app_copyright    = "Copyright (C) 2021 by Benjamin Kupka"
local app_license      = "GNU General Public License Version 3"
local app_env          = "Environment: " .. wxlua.wxLUA_VERSION_STRING
local app_build        = "Built with: "..wx.wxVERSION_STRING

local app_width        = 560 -- 405
local app_height       = 405 -- 470

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
}
local png_tbl = {

    [ 1 ] = RES_PATH .. "GPLv3_160x80.png",
    [ 2 ] = RES_PATH .. "osi_75x100.png",
    [ 3 ] = RES_PATH .. "appicon_16x16.png",
    [ 4 ] = RES_PATH .. "appicon_32x32.png",
    [ 5 ] = RES_PATH .. "appicon_16x16.ico"
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
local cfg_tbl = util_loadtable( db_tbl[ 1 ] ) or {}


--// Fonts
local font_default          = wx.wxFont( 8,  wx.wxMODERN, wx.wxNORMAL, wx.wxNORMAL, false, "Verdana" )
local font_about_normal_1   = wx.wxFont( 9,  wx.wxMODERN, wx.wxNORMAL, wx.wxNORMAL, false, "Verdana" )
local font_about_normal_2   = wx.wxFont( 10, wx.wxMODERN, wx.wxNORMAL, wx.wxNORMAL, false, "Verdana" )
local font_about_bold       = wx.wxFont( 10, wx.wxMODERN, wx.wxNORMAL, wx.wxFONTWEIGHT_BOLD, false, "Verdana" )
local font_timer_bold       = wx.wxFont( 14, wx.wxMODERN, wx.wxNORMAL, wx.wxFONTWEIGHT_BOLD, false, "Verdana" )
local font_timer_bold_2     = wx.wxFont( 18, wx.wxMODERN, wx.wxNORMAL, wx.wxFONTWEIGHT_BOLD, false, "Verdana" )
local font_timer_bold_3     = wx.wxFont( 22, wx.wxMODERN, wx.wxNORMAL, wx.wxFONTWEIGHT_BOLD, false, "Verdana" )
local font_timer_list       = wx.wxFont( 10, wx.wxMODERN, wx.wxNORMAL, wx.wxFONTWEIGHT_BOLD, false, "Verdana" )
local font_timer_status     = wx.wxFont( 13, wx.wxMODERN, wx.wxNORMAL, wx.wxFONTWEIGHT_BOLD, false, "Verdana" )
local font_timer_choice     = wx.wxFont( 9,  wx.wxMODERN, wx.wxNORMAL, wx.wxFONTWEIGHT_BOLD, false, "Verdana" )
local font_timer_btn        = wx.wxFont( 18, wx.wxMODERN, wx.wxNORMAL, wx.wxNORMAL, false, "Verdana" )
local font_alarm_btn        = wx.wxFont( 18, wx.wxMODERN, wx.wxNORMAL, wx.wxFONTWEIGHT_BOLD, false, "Verdana" )
local font_terminal         = wx.wxFont( 8,  wx.wxMODERN, wx.wxNORMAL, wx.wxNORMAL, false, "Lucida Console" )

--// controls
local control, di, result
local id_counter
local frame
local panel
local timer
local media_ctrl
local user_choice
local newtime_textctrl
local time_listbox
local time_add_button
local time_del_button
local status_textctrl
local timer_start_button
local timer_stop_button
local timer_remaining_time
local timer_gauge
local checkbox_trayicon

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
local sorted_array_time
local sorted_array_audio
local check_time
local get_next_time
local menu_item
local show_alert_window
local show_about_window
local show_settings_window
local show_tutorial_window
local add_time
local del_time
local status_blink
local add_taskbar

-------------------------------------------------------------------------------------------------------------------------------------
--// IDS //--------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------

--// ID generator
id_counter = wx.wxID_HIGHEST + 1
new_id = function() id_counter = id_counter + 1; return id_counter end

--// IDs
ID_mb_settings = new_id()
ID_mb_alarm = new_id()
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
save = function( )
    util_savetable( cfg_tbl, "cfg_tbl", db_tbl[ 1 ] )
end

--// check if its time for the alarm windows
get_current_time_infos = function( t )
    for k, v in pairs( cfg_tbl[ "time" ] ) do
        if ( v == t ) and ( alarmtime_done ~= t ) then
            alarmtime_done = t
            return true
        end
    end
    return false
end

--// toggle timer on/off
set_timer = function( mode, dialog ) -- mode: timer on/off (bool); dialog: send dialog if timer is off (bool)
    if mode then
        if not timer:IsRunning() then
            timer:Start( timer_i, timer_m )
            frame:SetStatusText( "Der Timer wurde gestartet...", 0 )
            frame:SetStatusText( "Timer: AN", 1 )
            if dialog then
                di = wx.wxMessageDialog( frame, "Der Timer wurde gestartet.", "Hinweis", wx.wxOK )
                di:ShowModal(); di:Destroy()
            end
        end
    else
        if timer:IsRunning() then
            timer:Stop()
            frame:SetStatusText( "Der Timer wurde gestoppt...", 0 )
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

--// sorted times array
sorted_array_time = function()
    local arr = {}
    local i = 1
    if tbl_key_exists( cfg_tbl, "time" ) and ( not tbl_is_empty( cfg_tbl[ "time" ] ) ) then
        for k, v in pairs( cfg_tbl[ "time" ] ) do
            table.insert( arr, i, v )
            i = i + 1
        end
        table.sort( arr )
    end
    return arr
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
    if not tbl_key_exists( cfg_tbl, "time" ) then
        cfg_tbl[ "time" ] = {}
        save()
    end
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

--// get the remaining time as string
get_next_time = function()
    if not tbl_is_empty( cfg_tbl[ "time" ] ) then
        local seconds_to_wait = 99999999999
        local time_next = ""

        local curr_sec   = os.date( "%S" )
        local curr_min   = os.date( "%M" )
        local curr_hour  = os.date( "%H" )
        local curr_day   = os.date( "%d" )
        local curr_month = os.date( "%m" )
        local curr_year  = os.date( "%Y" )
        local curr_time  = os.time()

        for k, v in pairs( cfg_tbl[ "time" ] ) do
            local t_hour = v:sub( 1, 2 )
            local t_min  = v:sub( 4, 5 )
            local t_time = os.time( { year = curr_year, month = curr_month, day = curr_day, hour = t_hour, min = t_min, sec = "00" } )

            if curr_time < t_time then
                local seconds = os.difftime( t_time, os.time() )
                if ( seconds > 0 ) and ( seconds < seconds_to_wait ) then
                    --print( "#1 t_hour: " .. t_hour .. "\tseconds:" .. seconds ) -- debug
                    seconds_to_wait = seconds
                    time_next = v
                end
            end
            if curr_time > t_time then
                local seconds = os.difftime( t_time, os.time() ) + 86400 -- + 1 day
                if ( seconds > 0 ) and ( seconds < seconds_to_wait ) then
                    --print( "#2 t_hour: " .. t_hour .. "\tseconds:" .. seconds ) -- debug
                    seconds_to_wait = seconds
                    time_next = v
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
end

-------------------------------------------------------------------------------------------------------------------------------------
--// MENUBAR & TASKBAR //------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------

--// icons taskbar
local tb_bmp_about_16x16  = wx.wxArtProvider.GetBitmap( wx.wxART_INFORMATION, wx.wxART_TOOLBAR )
local tb_bmp_exit_16x16   = wx.wxArtProvider.GetBitmap( wx.wxART_QUIT,        wx.wxART_TOOLBAR )

--// icons menubar
local bmp_settings_16x16  = wx.wxArtProvider.GetBitmap( wx.wxART_LIST_VIEW,   wx.wxART_TOOLBAR )
local bmp_testalarm_16x16 = wx.wxArtProvider.GetBitmap( wx.wxART_TIP,         wx.wxART_TOOLBAR )
local bmp_exit_16x16      = wx.wxArtProvider.GetBitmap( wx.wxART_QUIT,        wx.wxART_TOOLBAR )
local bmp_about_16x16     = wx.wxArtProvider.GetBitmap( wx.wxART_INFORMATION, wx.wxART_TOOLBAR )
local bmp_tutorial_16x16  = wx.wxArtProvider.GetBitmap( wx.wxART_INFORMATION, wx.wxART_TOOLBAR )

menu_item = function( menu, id, name, status, bmp )
    local mi = wx.wxMenuItem( menu, id, name, status )
    mi:SetBitmap( bmp )
    bmp:delete()
    return mi
end

local main_menu = wx.wxMenu()
main_menu:Append( menu_item( main_menu, ID_mb_settings, "Einstellungen" .. "\tF3", "Einstellungen öffnen", bmp_settings_16x16 ) )
main_menu:Append( menu_item( main_menu, ID_mb_alarm,    "Testalarm starten" .. "\tF8", "Testalarm starten", bmp_testalarm_16x16 ) )
main_menu:Append( menu_item( main_menu, wx.wxID_EXIT,   "Beenden" .. "\tF4", "Programm beenden", bmp_exit_16x16 ) )

local help_menu = wx.wxMenu()
help_menu:Append( menu_item( help_menu, ID_mb_tutorial, "Anleitung" .. "\tF1", "Bedienungsanleitung für das" .. " " .. app_name, bmp_tutorial_16x16 ) )
help_menu:Append( menu_item( help_menu, wx.wxID_ABOUT,  "Über" .. "\tF2", "Informationen über das" .. " " .. app_name, bmp_about_16x16 ) )

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
--// TIMER & MEDIA //----------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------

--// timer
timer = nil
timer = wx.wxTimer( panel )

--// media
media_ctrl = wx.wxMediaCtrl( frame, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxSize( 0, 0 ) )

--// media - load current signalton from table
load_current_signaltone_selection = function( control )
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
    control:Load( file )
    control:SetVolume( volume )
    if need_save then
        save()
    end
end

load_current_signaltone_selection( media_ctrl )

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

-------------------------------------------------------------------------------------------------------------------------------------
--// DIALOG WINDOWS //---------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------

--// add taskbar (systemtrray)
local taskbar = nil
add_taskbar = function( frame )
    if not tbl_key_exists( cfg_tbl, "taskbar" ) then
        cfg_tbl[ "taskbar" ] = false
        save()
    end
    if cfg_tbl[ "taskbar" ] == true then
        taskbar = wx.wxTaskBarIcon()
        local icon = wx.wxIcon( png_tbl[ 5 ], 3, 16, 16 )
        taskbar:SetIcon( icon, app_name .. " " .. _VERSION )

        local menu = wx.wxMenu()
        tb_bmp_about_16x16 = wx.wxArtProvider.GetBitmap( wx.wxART_INFORMATION, wx.wxART_TOOLBAR )
        tb_bmp_exit_16x16  = wx.wxArtProvider.GetBitmap( wx.wxART_QUIT,        wx.wxART_TOOLBAR )

        menu:Append( menu_item( menu, wx.wxID_ABOUT,  "Über" .. "\tF2", "Informationen über das" .. " " .. app_name, tb_bmp_about_16x16 ) )
        menu:Append( menu_item( menu, wx.wxID_EXIT,   "Beenden" .. "\tF4", "Programm beenden", tb_bmp_exit_16x16 ) )

        menu:Connect( wx.wxID_ABOUT, wx.wxEVT_COMMAND_MENU_SELECTED,
            function( event )
                show_about_window( frame )
            end
        )
        menu:Connect( wx.wxID_EXIT, wx.wxEVT_COMMAND_MENU_SELECTED,
            function( event )
                frame:Close( true )
            end
        )
        taskbar:Connect( wx.wxEVT_TASKBAR_RIGHT_DOWN,
            function( event )
                taskbar:PopupMenu( menu )
            end
        )
        taskbar:Connect( wx.wxEVT_TASKBAR_LEFT_DOWN,
            function( event )
                frame:Iconize( not frame:IsIconized() )
                -- new
                local show = not frame:IsIconized()
                if show then
                    frame:Raise( true )
                end
            end
        )
        frame:Connect( wx.wxEVT_ICONIZE,
            function( event )
                local show = not frame:IsIconized()
                frame:Show( show )
                if show then
                    frame:Raise( true )
                end
            end
        )
    else
        if taskbar then
            frame:Connect( wx.wxEVT_ICONIZE,
                function( event )
                    local show = not frame:IsIconized()
                    frame:Show( true )
                    if show then
                        frame:Raise( true )
                    end
                end
            )
            taskbar:delete()
        end
        taskbar = nil
    end
    return taskbar
end

--// alarm window
show_alert_window = function( t )
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
    di_tim:SetBackgroundColour( wx.wxColour( 234, 210, 0 ) )

    --// app logo
    local app_logo = wx.wxBitmap():ConvertToImage()
    app_logo:LoadFile( png_tbl[ 4 ] )

    control = wx.wxStaticBitmap( di_tim, wx.wxID_ANY, wx.wxBitmap( app_logo ), wx.wxPoint( 0, 20 ), wx.wxSize( app_logo:GetWidth(), app_logo:GetHeight() ) )
    control:Centre( wx.wxHORIZONTAL )
    app_logo:Destroy()

    --// app name / version
    control = wx.wxStaticText( di_tim, wx.wxID_ANY, app_name .. " " .. app_version, wx.wxPoint( 0, 65 ) )
    control:SetFont( font_about_bold )
    control:Centre( wx.wxHORIZONTAL )

    --// horizontal line
    control = wx.wxStaticLine( di_tim, wx.wxID_ANY, wx.wxPoint( 0, 155 ), wx.wxSize( 250, 2 ) )
    control:Centre( wx.wxHORIZONTAL )

    --// text
    control = wx.wxStaticText( di_tim, wx.wxID_ANY, "Es ist " .. t .. " Uhr", wx.wxPoint( 0, 175 ) )
    control:SetFont( font_timer_bold )
    control:Centre( wx.wxHORIZONTAL )

    --// text
    control = wx.wxStaticText( di_tim, wx.wxID_ANY, "NSC anrufen nicht vergessen!", wx.wxPoint( 0, 215 ) )
    control:SetFont( font_timer_bold )
    control:Centre( wx.wxHORIZONTAL )

    --// horizontal line
    control = wx.wxStaticLine( di_tim, wx.wxID_ANY, wx.wxPoint( 0, 260 ), wx.wxSize( 400, 2 ) )
    control:Centre( wx.wxHORIZONTAL )

    --// button "OK"
    local btn_close = wx.wxButton( di_tim, wx.wxID_ANY, "OK", wx.wxPoint( 0, 360 ), wx.wxSize( 90, 60 ) )
    btn_close:SetBackgroundColour( wx.wxColour( 255, 255, 255 ) )
    btn_close:Centre( wx.wxHORIZONTAL )
    btn_close:SetFont( font_alarm_btn )
    btn_close:SetBackgroundColour( wx.wxColour( 0, 0, 0 ) )
    btn_close:SetForegroundColour( wx.wxColour( 234, 210, 0 ) )

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
    control:SetFont( font_about_bold )
    control:Centre( wx.wxHORIZONTAL )

    --// app copyright
    control = wx.wxStaticText( di_abo, wx.wxID_ANY, app_copyright, wx.wxPoint( 0, 90 ) )
    control:SetFont( font_about_normal_2 )
    control:Centre( wx.wxHORIZONTAL )

    --// environment
    control = wx.wxStaticText( di_abo, wx.wxID_ANY, app_env, wx.wxPoint( 0, 122 ) )
    control:SetFont( font_about_normal_2 )
    control:Centre( wx.wxHORIZONTAL )

    --// build with
    control = wx.wxStaticText( di_abo, wx.wxID_ANY, app_build, wx.wxPoint( 0, 137 ) )
    control:SetFont( font_about_normal_2 )
    control:Centre( wx.wxHORIZONTAL )

    --// horizontal line
    control = wx.wxStaticLine( di_abo, wx.wxID_ANY, wx.wxPoint( 0, 168 ), wx.wxSize( 275, 1 ) )
    control:Centre( wx.wxHORIZONTAL )

    --// license
    control = wx.wxStaticText( di_abo, wx.wxID_ANY, app_license, wx.wxPoint( 0, 180 ) )
    control:SetFont( font_about_normal_2 )
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
    if not tbl_key_exists( cfg_tbl, "taskbar" ) then
        cfg_tbl[ "taskbar" ] = false
        save()
    end
    local di_set = wx.wxDialog(
        wx.NULL,
        wx.wxID_ANY,
        "Einstellungen",
        wx.wxDefaultPosition,
        wx.wxSize( 155, 430 ),
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
    control = wx.wxStaticBox( di_set, wx.wxID_ANY, "Lautstärke", wx.wxPoint( 10, 220 ), wx.wxSize( 127, 75 ) )

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
    local settings_btn_test = wx.wxButton( di_set, wx.wxID_ANY, "Test", wx.wxPoint( 12, 265 ), wx.wxSize( 60, 20 ) )
    settings_btn_test:SetBackgroundColour( wx.wxColour( 255, 255, 255 ) )
    settings_btn_test:Centre( wx.wxHORIZONTAL )

    --// event - button "Test"
    settings_btn_test:Connect( wx.wxID_ANY, wx.wxEVT_COMMAND_BUTTON_CLICKED,
    function( event )
        media_control( media_ctrl, "play" ) -- mode: "play" "pause" "stop"
    end )

    --// border
    control = wx.wxStaticBox( di_set, wx.wxID_ANY, "", wx.wxPoint( 10, 305 ), wx.wxSize( 127, 37 ) )

    --// minimize to tray
    checkbox_trayicon = wx.wxCheckBox( di_set, wx.wxID_ANY, "Minimiere zu Tray", wx.wxPoint( 23, 320 ), wx.wxDefaultSize )

    --// events - minimize to tray
    checkbox_trayicon:Connect( wx.wxID_ANY, wx.wxEVT_COMMAND_CHECKBOX_CLICKED,
    function( event )
        if checkbox_trayicon:IsChecked() then
            cfg_tbl[ "taskbar" ] = true
            save()
        else
            cfg_tbl[ "taskbar" ] = false
            save()
        end
        add_taskbar( frame, checkbox_trayicon )
    end )

    if cfg_tbl[ "taskbar" ] == true then
        checkbox_trayicon:SetValue( true )
    else
        checkbox_trayicon:SetValue( false )
    end

    --// button "OK"
    local settings_btn_ok = wx.wxButton( di_set, wx.wxID_ANY, "OK", wx.wxPoint( 75, 370 ), wx.wxSize( 60, 20 ) )
    settings_btn_ok:SetBackgroundColour( wx.wxColour( 255, 255, 255 ) )
    settings_btn_ok:Centre( wx.wxHORIZONTAL )

    --// event - button "OK"
    settings_btn_ok:Connect( wx.wxID_ANY, wx.wxEVT_COMMAND_BUTTON_CLICKED,
    function( event )
        local choice = alarm_radio:GetSelection() + 1
        local volume = media_ctrl:GetVolume()
        cfg_tbl[ "signaltone" ] = choice
        cfg_tbl[ "volume" ] = volume
        save()
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
        wx.wxSize( 490, 425 ),
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
    control:SetFont( font_about_bold )
    control:Centre( wx.wxHORIZONTAL )

    --// credits
    control = wx.wxTextCtrl(
        di_tut,
        wx.wxID_ANY,

        "Schritt 1:\n\n" ..
        " Links bei Timer Einstellungen werden die Zeiten eingetragen.\n" ..
        " Das Schema (hh:mm) muss beachtet werden. Beispiele:\n\n" ..
        "   00:10 = richtig\n" ..
        "    0:10 = falsch\n" ..
        "   05:20 = richtig\n" ..
        "    5:20 = falsch\n\n" ..
        "Schritt 2:\n\n" ..
        " Nachdem für den Timer Zeiten eingetragen wurden,\n" ..
        " muss rechts nur noch auf START geklickt werden.\n" ..
        " Fertig." ..
        "\n\nTipp:\n\n" ..
        "   Unter \"Menü / Einstellungen\" oben links gibt es eine\n" ..
        "   Auswahl verschiedener Alarmtöne.\n\n",
        wx.wxPoint( 5, 95 ),
        wx.wxSize( 460, 255 ),
        wx.wxTE_READONLY + wx.wxTE_MULTILINE + wx.wxTE_RICH + wx.wxSUNKEN_BORDER + wx.wxHSCROLL
    )
    control:SetFont( font_terminal )
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
--// Panel elements //---------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------

--// border
control = wx.wxStaticBox( panel, wx.wxID_ANY, "Timer Einstellungen  (Schema: hh:mm)", wx.wxPoint( 20, 10 ), wx.wxSize( 200, 310 ) )

--// newtime_textctrl
newtime_textctrl = wx.wxTextCtrl( panel, wx.wxID_ANY, "", wx.wxPoint( 32, 35 ), wx.wxSize( 50, 20 ), wx.wxTE_PROCESS_ENTER + wx.wxTE_CENTRE )
newtime_textctrl:SetBackgroundColour( wx.wxColour( 255, 255, 255 ) )
newtime_textctrl:SetMaxLength( 5 )

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

--// button "hinzufügen"
time_add_button = wx.wxButton( panel, wx.wxID_ANY, "Hinzufügen", wx.wxPoint( 87, 35 ), wx.wxSize( 120, 21 ) )
time_add_button:Disable()

--// time_listbox
time_listbox = wx.wxListBox( panel, wx.wxID_ANY, wx.wxPoint( 32, 60 ), wx.wxSize( 175, 222 ), sorted_array_time(), wx.wxLB_SINGLE + wx.wxLB_HSCROLL + wx.wxLB_SORT + wx.wxSUNKEN_BORDER )
time_listbox:SetSelection( -1 ) -- markup no entry
time_listbox:SetFont( font_timer_list )

--// button "löschen"
time_del_button = wx.wxButton( panel, wx.wxID_ANY, "Löschen", wx.wxPoint( 32, 287 ), wx.wxSize( 175, 21 ) )
time_del_button:Disable()

--// database - add new time
add_time = function( newtime_textctrl, time_listbox )
    local tTime = newtime_textctrl:GetValue()
    local check, err = check_time( tTime )
    local time_exists, need_save = false, false
    if check then
        for k, v in pairs( cfg_tbl ) do
            if k == "time" then
                for key, value in pairs( v ) do
                    if value == tTime then time_exists = true end
                end
            end
        end
        if time_exists then
            di = wx.wxMessageDialog( frame, "Ein Eintrag mit dieser Uhrzeit existiert bereits.", "Hinweis", wx.wxOK + wx.wxCENTRE )
            di:ShowModal(); di:Destroy()
            time_add_button:Disable()
            time_del_button:Disable()
        else
            table.insert( cfg_tbl[ "time" ], tTime )
            need_save = true
            -- dialog
            di = wx.wxMessageDialog( frame, "Uhrzeit hinzugefügt: " .. tTime, "Hinweis", wx.wxOK )
            di:ShowModal(); di:Destroy()
        end
        if need_save then
            save()
            newtime_textctrl:SetValue( "" )
            time_listbox:Set( sorted_array_time() )
            time_listbox:SetSelection( -1 ) -- markup no entry
            time_add_button:Disable()
            time_del_button:Disable()
            status_textctrl:SetForegroundColour( wx.wxColour( 255, 0, 0 ) )
            status_textctrl:SetValue( ">  D E A K T I V I E R T  <" )
            timer_next_time:SetValue( "" )
            timer_remaining_time:SetValue( "" )
            timer_gauge:SetValue( 0 )
            timer_start_button:Enable( true )
            timer_stop_button:Disable()
            -- timer
            set_timer( false, true ) -- mode: timer on/off (bool); dialog: send dialog if timer is off (bool)
        end
    else
        newtime_textctrl:SetValue( "" )
        time_add_button:Disable()
        -- dialog
        di = wx.wxMessageDialog( frame, "Fehler: Keine gültige Eingabe." .. "\n\n" .. err, "Hinweis", wx.wxOK )
        di:ShowModal(); di:Destroy()
    end
end

--// database - delete time
del_time = function( newtime_textctrl, time_listbox )
    if time_listbox:GetSelection() == -1 then
        -- dialog
        di = wx.wxMessageDialog( frame, "Fehler: Keine Uhrzeit ausgewählt.", "Hinweis", wx.wxOK )
        di:ShowModal(); di:Destroy()
    else
        -- del time
        local tTime = time_listbox:GetString( time_listbox:GetSelection() )
        for k, v in pairs( cfg_tbl[ "time" ] ) do
            if v == tTime then
                table.remove( cfg_tbl[ "time" ], k )
            end
        end
        save()
        newtime_textctrl:SetValue( "" )
        time_listbox:Set( sorted_array_time() )
        time_listbox:SetSelection( -1 ) -- markup no entry
        time_add_button:Disable()
        time_del_button:Disable()
        status_textctrl:SetForegroundColour( wx.wxColour( 255, 0, 0 ) )
        status_textctrl:SetValue( ">  D E A K T I V I E R T  <" )
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
    add_time( newtime_textctrl, time_listbox )
end )

--// event - time_del_button
time_del_button:Connect( wx.wxID_ANY, wx.wxEVT_COMMAND_BUTTON_CLICKED,
function( event )
    del_time( newtime_textctrl, time_listbox )
end )

--// event - newtime_textctrl
newtime_textctrl:Connect( wx.wxID_ANY, wx.wxEVT_COMMAND_TEXT_UPDATED,
function( event )
    if newtime_textctrl:GetValue() ~= "" then
        time_add_button:Enable( true )
    end
end )

--// event - time_listbox
time_listbox:Connect( wx.wxID_ANY, wx.wxEVT_COMMAND_LISTBOX_SELECTED,
function( event )
    time_del_button:Enable( true )
end )

--// border
control = wx.wxStaticBox( panel, wx.wxID_ANY, "Timer Status", wx.wxPoint( 245, 10 ), wx.wxSize( 290, 310 ) )

--// status_textctrl
status_textctrl = wx.wxTextCtrl( panel, wx.wxID_ANY, "", wx.wxPoint( 257, 35 ), wx.wxSize( 266, 28 ), wx.wxTE_READONLY + wx.wxTE_CENTRE )-- + wx.wxNO_BORDER )
status_textctrl:SetBackgroundColour( wx.wxColour( 40, 40, 40 ) )
status_textctrl:SetFont( font_timer_status )
status_textctrl:SetForegroundColour( wx.wxColour( 255, 0, 0 ) )
status_textctrl:SetValue( ">  D E A K T I V I E R T  <" )

--// button - Timer start
timer_start_button = wx.wxButton( panel, wx.wxID_ANY, "START", wx.wxPoint( 257, 73 ), wx.wxSize( 130, 98 ) )
timer_start_button:SetBackgroundColour( wx.wxColour( 180, 180, 180 ) )
timer_start_button:SetFont( font_timer_btn )

--// button - Timer stop
timer_stop_button = wx.wxButton( panel, wx.wxID_ANY, "STOP", wx.wxPoint( 392, 73 ), wx.wxSize( 130, 98 ) )
timer_stop_button:SetBackgroundColour( wx.wxColour( 180, 180, 180 ) )
timer_stop_button:SetFont( font_timer_btn )
timer_stop_button:Disable()

--// text
control = wx.wxStaticText( panel, wx.wxID_ANY, "Fortschritt:", wx.wxPoint( 258, 180 ) )

--// timer_gauge
timer_gauge = wx.wxGauge( panel, wx.wxID_ANY, gauge_max_range, wx.wxPoint( 258, 196 ), wx.wxSize( 264, 23 ), wx.wxGA_HORIZONTAL + wx.wxGA_SMOOTH )

--// text
control = wx.wxStaticText( panel, wx.wxID_ANY, "Nächste Uhrzeit:", wx.wxPoint( 258, 230 ) )

--// timer_next_time
timer_next_time = wx.wxTextCtrl( panel, wx.wxID_ANY, "", wx.wxPoint( 257, 245 ), wx.wxSize( 266, 22 ), wx.wxTE_READONLY + wx.wxTE_CENTRE + wx.wxSUNKEN_BORDER )
timer_next_time:SetFont( font_timer_choice )
timer_next_time:SetBackgroundColour( wx.wxColour( 210, 210, 210 ) )

--// text
control = wx.wxStaticText( panel, wx.wxID_ANY, "Verbleibende Zeit:", wx.wxPoint( 258, 270 ) )

--// timer_remaining_time
timer_remaining_time = wx.wxTextCtrl( panel, wx.wxID_ANY, "", wx.wxPoint( 257, 285 ), wx.wxSize( 266, 22 ), wx.wxTE_READONLY + wx.wxTE_CENTRE + wx.wxSUNKEN_BORDER )
timer_remaining_time:SetFont( font_timer_choice )
timer_remaining_time:SetBackgroundColour( wx.wxColour( 210, 210, 210 ) )

--// event - timer_start_button
timer_start_button:Connect( wx.wxID_ANY, wx.wxEVT_COMMAND_BUTTON_CLICKED,
function( event )
    local time_next, time_remaining, seconds = get_next_time()
    gauge_seconds = 0
    if ( not tbl_is_empty( cfg_tbl[ "time" ] ) ) then
        timer_start_button:Disable()
        timer_stop_button:Enable( true )
        time_listbox:SetSelection( -1 ) -- markup no entry
        time_add_button:Disable()
        time_del_button:Disable()
        newtime_textctrl:Disable()
        time_listbox:Disable()
        status_textctrl:SetForegroundColour( wx.wxColour( 80, 240, 114 ) )
        status_textctrl:SetValue( ">     A K T I V I E R T     <" )
        timer_gauge:SetRange( seconds )
        timer_gauge:SetValue( gauge_seconds )
        -- timer
        set_timer( true, false ) -- mode: timer on/off (bool); dialog: send dialog if timer is off (bool)
    else
        -- dialog
        di = wx.wxMessageDialog( frame, "Die Liste enthält keine Zeiten.", "Hinweis", wx.wxOK )
        di:ShowModal(); di:Destroy()
    end

end )
timer_start_button:Connect( wx.wxID_ANY, wx.wxEVT_ENTER_WINDOW,
function( event )
    frame:SetStatusText( "Timer starten", 0 )
end )
timer_start_button:Connect( wx.wxID_ANY, wx.wxEVT_LEAVE_WINDOW,
function( event )
    frame:SetStatusText( "", 0 )
end )

--// event - timer_stop_button
timer_stop_button:Connect( wx.wxID_ANY, wx.wxEVT_COMMAND_BUTTON_CLICKED,
function( event )
    -- tab 4 changes
    timer_start_button:Enable( true )
    timer_stop_button:Disable()
    time_add_button:Enable( true )
    time_listbox:Enable( true )
    newtime_textctrl:Enable( true )
    status_textctrl:SetForegroundColour( wx.wxColour( 255, 0, 0 ) )
    status_textctrl:SetValue( ">  D E A K T I V I E R T  <" )
    timer_next_time:SetValue( "" )
    timer_remaining_time:SetValue( "" )
    timer_gauge:SetRange( 10 )
    timer_gauge:SetValue( 0 )
    -- timer
    set_timer( false, false ) -- mode: timer on/off (bool); dialog: send dialog if timer is off (bool)
end )
timer_stop_button:Connect( wx.wxID_ANY, wx.wxEVT_ENTER_WINDOW,
function( event )
    frame:SetStatusText( "Timer stoppen", 0 )
end )
timer_stop_button:Connect( wx.wxID_ANY, wx.wxEVT_LEAVE_WINDOW,
function( event )
    frame:SetStatusText( "", 0 )
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

-------------------------------------------------------------------------------------------------------------------------------------
--// MAIN LOOP //--------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------

--// event - timer
panel:Connect( wx.wxEVT_TIMER, -- timer iteration
function( event )
    local t = os.date( "%H:%M" )
    local alarm = get_current_time_infos( t )
    local time_next, time_remaining, seconds = get_next_time()
    if alarm then
        show_alert_window( t )
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
        local taskbar = add_taskbar( frame )
        frame:Show( true )
        frame:Connect( wx.wxEVT_CLOSE_WINDOW,
        function( event )
            di = wx.wxMessageDialog( frame, "Wirklich beenden?", "Hinweis", wx.wxYES_NO + wx.wxICON_QUESTION + wx.wxCENTRE )
            result = di:ShowModal(); di:Destroy()
            if result == wx.wxID_YES then
                if taskbar then taskbar:delete() end
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
        frame:Connect( ID_mb_alarm, wx.wxEVT_COMMAND_MENU_SELECTED,
        function( event )
            show_alert_window( "[ TESTALARM ]" )
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