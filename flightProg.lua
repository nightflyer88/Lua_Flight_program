--[[
    ---------------------------------------------------------
    Flight program training app. Each flight figure is announced by the app, 
    it is therefore not necessary to look at the transmitter. 
    An optional background music can also be played.


    ---------------------------------------------------------

    V1.0    29.07.18    initial release

--]]

----------------------------------------------------------------------
-- Locals for the application
local appVersion="1.0"
local lang

local program={name, procedure=1, backgroundMusic, prog={}}
local progPath="Apps/flightProg/Prog"
local musicPath="Music"

local startSwitch,cancelSwitch
local startIndex
local progRun=-1
local curProgIndex=0
local lastTime,lastTimeSwitch=0,0
local formView
local musicList={}


----------------------------------------------------------------------
-- Read translations
local function setLanguage()
    local lng=system.getLocale()
    local file=io.readall("Apps/flightProg/flightProg.jsn")
    local obj=json.decode(file)
    if(obj) then
        lang=obj[lng] or obj[obj.default]
    end
end


----------------------------------------------------------------------
-- Store settings when changed by user
local function saveProgram()
    local file = io.open(progPath.."/"..program.name..".jsn","w")
    if(file) then
        local json_text = json.encode(program)
        io.write(file, json_text)
        io.close(file)
        system.pSave("program",program.name)
    end
end

local function readProgram()
    local file = io.open(progPath.."/"..program.name..".jsn","r")
    if(file) then
        local json_text=io.readall(progPath.."/"..program.name..".jsn")
        program=json.decode(json_text)
        io.close(file)
        if(not program.backgroundMusic) then
            program.backgroundMusic=""
        end
    end
end

local function nameChanged(value)
    program.name = value
    saveProgram()
end

local function startSwitchChanged(value)
    startSwitch=value
    system.pSave("startSwitch",value)
end

local function cancelSwitchChanged(value)
    cancelSwitch=value
    system.pSave("cancelSwitch",value)
end

local function procedureChanged(value)
    program.procedure = value
    saveProgram()
end

local function backgroundMusicChanged(value)
    program.backgroundMusic = musicList[value]
    saveProgram()
end

----------------------------------------------------------------------
-- Latches the current keyCode
local function keyForm(keyCode)
    if(formView==1)then
        if(keyCode==KEY_1)then
            -- open flight program
            saveProgram()
            form.reinit(2)
        elseif(keyCode==KEY_2)then
            -- add audio file
            local index=form.getFocusedRow() - startIndex
            if(index>0)then
                if(index<= #program.prog)then
                    table.insert(program.prog, index+1, "")
                else
                    table.insert(program.prog, "")
                end
                form.reinit(1)
            end
        elseif(keyCode==KEY_3)then
            -- add timer
            local index=form.getFocusedRow() - startIndex
            if(index>0)then
                if(index<= #program.prog)then
                    table.insert(program.prog, index+1, 10)
                else
                    table.insert(program.prog, 10)
                end
                form.reinit(1)
            end
        elseif(keyCode==KEY_4)then
            -- delete item
            local index=form.getFocusedRow() - startIndex
            if(index>0 and index<= #program.prog)then
                table.remove(program.prog, index)
                form.reinit(1)
            end
        end
    elseif(formView==2)then
        if(keyCode==KEY_1)then
            -- main menu
            form.reinit(1)
        end
    end
    
    if(keyCode==KEY_5 or keyCode==KEY_ESC)then
        -- exit app
        saveProgram()
    end
end

----------------------------------------------------------------------
-- Draw the main form (Application menu inteface)
local function initForm(subform)
    formView=subform
    if(subform==1)then
        -- main menu
        form.setTitle(lang.appName)
        form.setButton(1,":folder",ENABLED)
        form.setButton(2,":sndOn",ENABLED)
        form.setButton(3,":timer",ENABLED)
        form.setButton(4,":delete",ENABLED)

        form.addRow(2)
        form.addLabel({label=lang.progName})
        form.addTextbox(program.name,20,nameChanged)

        form.addRow(2)
        form.addLabel({label=lang.startSwitch})
        form.addInputbox(startSwitch,true,startSwitchChanged)

        form.addRow(2)
        form.addLabel({label=lang.cancelSwitch})
        form.addInputbox(cancelSwitch,true,cancelSwitchChanged)

        form.addRow(2)
        form.addLabel({label=lang.procedure}) form.addSelectbox({lang.auto,lang.singleStep,lang.teachInTime},program.procedure,false,procedureChanged)
        
        form.addRow(2)
        form.addLabel({label=lang.backgroundMusic})
        local index={} 
        for k,v in pairs(musicList) do 
            index[v]=k 
        end 
        form.addSelectbox(musicList, index[program.backgroundMusic]or 1,true,backgroundMusicChanged)

        form.addLabel({label="",font=FONT_MINI})
        form.addLabel({label=lang.program,font=FONT_BOLD})

        startIndex = 7

        for i, v in ipairs(program.prog) do
            if(type(v)=="string")then
                form.addRow(2)
                form.addLabel({label=lang.voiceOutput})
                form.addAudioFilebox(program.prog[i], function(value) program.prog[i]=value end)
            elseif(type(v)=="number")then
                form.addRow(2)
                form.addLabel({label=lang.waitingTime})
                form.addIntbox(program.prog[i],10,18000,0,1,1, function(value) program.prog[i]=value end)
            end
        end

        form.addRow(1)
        form.addLabel({label="Powered by M.Lehmann V"..appVersion.." ",font=FONT_MINI,alignRight=true})
    elseif(subform==2)then
        -- open flight program
        form.setTitle(lang.selectFile)
        form.setButton(1,"Esc",ENABLED)

        for name, filetype, size in dir(progPath) do
            if string.sub(name,1,1) ~= "." then
                if filetype=="file" then
                    local progName = string.sub(name, 1, string.len(name)-4)
                    form.addRow(2)
                    form.addLink((function() 
                                    program.name=progName
                                    readProgram()
                                    form.reinit(1) 
                                end),
                    {label = progName,width=150})
                    form.addLabel({label=string.format("%.1f",(size/1000)).."KB",alignRight=true})
                end
            end
        end 
    end
end



----------------------------------------------------------------------
-- Runtime functions
local function loop()
    -- get switch status
    local startVal,cancelVal = system.getInputsVal(startSwitch,cancelSwitch)
    if(startVal)then
        local newTimeSwitch = system.getTimeCounter() 
        local deltaTimeSwitch = newTimeSwitch - lastTimeSwitch
        if(startVal>0.5 and deltaTimeSwitch>1000) then
            -- start flight program
            lastTimeSwitch=system.getTimeCounter()
            if(progRun == -1) then
                -- play background music
                system.playFile("/"..musicPath.."/"..program.backgroundMusic, AUDIO_BACKGROUND)
            end
            progRun=1
        end
    end
    if(cancelVal)then
        if(cancelVal>0.5 and progRun ~= -1) then
            -- cancel flight programm
            progRun=-1 
            curProgIndex=0
            system.stopPlayback()
            system.messageBox(lang.cancelFlight, 2)
        end
    end
    
    -- main work
    if(progRun==1 and curProgIndex <= #program.prog)then
        if(curProgIndex==0)then
            system.messageBox(lang.beginFlight, 2)
            curProgIndex=1
            lastTime=system.getTimeCounter()
        end
        if(program.procedure==1)then
            -- auto
            if(type(program.prog[curProgIndex])=="string")then
                lastTime=system.getTimeCounter()
                system.playFile(program.prog[curProgIndex],AUDIO_IMMEDIATE)
                curProgIndex=curProgIndex+1
            elseif(type(program.prog[curProgIndex])=="number")then
                local newTime = system.getTimeCounter() 
                local deltaTime = (newTime - lastTime)/100
                if(deltaTime>=program.prog[curProgIndex])then
                    curProgIndex=curProgIndex+1
                    lastTime=system.getTimeCounter()
                end
            end     
        elseif(program.procedure==2)then
            -- single step
            if(type(program.prog[curProgIndex])=="string")then
                system.playFile(program.prog[curProgIndex],AUDIO_IMMEDIATE)
                curProgIndex=curProgIndex+1
            end
            if(type(program.prog[curProgIndex])=="number")then
                curProgIndex=curProgIndex+1
            end 
            progRun=0 -- stop program
        elseif(program.procedure==3)then
            -- Teach in time
            if(type(program.prog[curProgIndex])=="number")then
                local newTime = system.getTimeCounter() 
                local deltaTime = (newTime - lastTime)/100
                if(deltaTime>10)then
                    lastTime=system.getTimeCounter()
                    program.prog[curProgIndex] = deltaTime
                    curProgIndex=curProgIndex+1
                end
            end
            if(type(program.prog[curProgIndex])=="string")then
                lastTime=system.getTimeCounter()
                system.playFile(program.prog[curProgIndex],AUDIO_IMMEDIATE)
                curProgIndex=curProgIndex+1
            end
            progRun=0 -- stop program
        end
    end
    
    -- flight program finished
    if(#program.prog > 0 and curProgIndex > #program.prog)then
        progRun=-1 
        curProgIndex=0
        if(program.procedure==3)then
            -- Teach in time
            saveProgram()
            form.reinit(1)
        end
        system.messageBox(lang.endFlight, 2)
    end
end

----------------------------------------------------------------------
-- Application initialization
local function init()
    -- read music folder
    for name, filetype, size in dir(musicPath) do
        if name == "." then
            table.insert(musicList, "...")
        elseif name ~= ".." then
            if string.sub(name,1,1) ~= "." then
                table.insert(musicList, name)
            end
        end
    end
    
    program.name=system.pLoad("program","Prog1")
    readProgram()
    startSwitch = system.pLoad("startSwitch")
    cancelSwitch = system.pLoad("cancelSwitch")
    system.registerForm(1,MENU_APPS,lang.appName,initForm,keyForm)
end

----------------------------------------------------------------------
setLanguage()
return {init=init,loop=loop,author="M.Lehmann",version=appVersion,name=lang.appName}
