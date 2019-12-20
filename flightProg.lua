--[[
    ---------------------------------------------------------
    Flight program training app. Each flight figure is announced by the app, 
    it is therefore not necessary to look at the transmitter. 
    An optional background music can also be played.


    ---------------------------------------------------------

    V1.1    25.07.19    added filebox lib - audio files can be placed in different folders 
    V1.0    29.07.18    initial release

--]]

----------------------------------------------------------------------
-- Locals for the application
local appVersion="1.1"
local lang

local new_program={name="new", procedure=1, backgroundMusic = "...", prog={}}
local program = {}
local progPath="/Apps/flightProg/Prog"
local audioPath="/"

local startSwitch,cancelSwitch
local startIndex, formView
local progRun=-1
local curProgIndex=0
local lastTime,lastTimeSwitch=0,0

local editProgIndex=-1

-- filebox lib
local openfile = require("flightProg/filebox")

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
-- helper functions
local function getProgramFilePath(filename)
    local filePath = ""
    if (string.find(filename, '/', 1, true) or string.find(filename, ".jsn", 1))then
        filePath = filename
    else
        filePath = progPath.."/"..filename..".jsn"
    end
    return filePath
end

function tablecopy(t)
  local t2 = {}
  for k,v in pairs(t) do
    t2[k] = v
  end
  return t2
end


----------------------------------------------------------------------
-- Store settings when changed by user
local function saveProgram()
    local file = io.open(getProgramFilePath(program.name),"w")
    if(file) then
        local json_text = json.encode(program)
        io.write(file, json_text)
        io.close(file)
        system.pSave("program",program.name)
    end
end

local function readProgram()
    local filePath = getProgramFilePath(program.name)
    local file = io.open(filePath,"r")
    if(file) then
        local json_text=io.readall(filePath)
        program=json.decode(json_text)
        io.close(file)
        if(program.backgroundMusic == nil) then
            program.backgroundMusic = "..."
        end
    end
end

local function newProgram()
    saveProgram()
    program=tablecopy(new_program)
    --readProgram()
    form.reinit(1)
end

local function deleteProgram(file)
    if(file)then
        if(form.question(lang.deleteFileQuestion,"",file,10000,false,1000) > 0)then
            io.remove(file)         
        end
    end
end

local function nameChanged(value)
    local oldProgramName = getProgramFilePath(program.name)
    local newProgramName = openfile.getFilePath(oldProgramName).."/"..value..".jsn"
    io.rename(oldProgramName, newProgramName)
    program.name = newProgramName
    saveProgram()
end

local function startSwitchChanged(value)
    startSwitch = value
    system.pSave("startSwitch",value)
end

local function cancelSwitchChanged(value)
    cancelSwitch = value
    system.pSave("cancelSwitch",value)
end

local function procedureChanged(value)
    program.procedure = value
    saveProgram()
end

local function audioChanged(value)
    if(value ~= nil)then
        if(editProgIndex > 0)then
            program.prog[editProgIndex] = value
        elseif(editProgIndex == 0)then
            program.backgroundMusic = value
        end
        editProgIndex = -1
        saveProgram()
    end
end

local function programChanged(file)
    if(file ~= nil)then
        program.name = file
        readProgram()
    end
end


----------------------------------------------------------------------
-- Latches the current keyCode
local function keyForm(keyCode)
    openfile.updatekey(formView,keyCode)
    
    if(formView==1)then
        if(keyCode==KEY_1)then
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
        elseif(keyCode==KEY_2)then
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
        elseif(keyCode==KEY_3)then
            -- delete item
            local index=form.getFocusedRow() - startIndex
            if(index>0 and index<= #program.prog)then
                table.remove(program.prog, index)
                form.reinit(1)
            end
        end
        
        if(keyCode==KEY_5 or keyCode==KEY_ESC)then
        -- exit app
        saveProgram()
        end
    end
end

----------------------------------------------------------------------
-- Draw the main form (Application menu inteface)
local function initForm(subform)
    openfile.updateform(subform)
    
    formView=subform
    if(subform==1)then
        -- main menu
        form.setTitle(lang.appName)
        form.setButton(1,":sndOn",ENABLED)
        form.setButton(2,":timer",ENABLED)
        form.setButton(3,":delete",ENABLED)
        
        -- open program
        form.addRow(2)
        form.addIcon(":folder",{width=30, enabled = false})
        form.addLink((function()
                        saveProgram()
                        openfile.openfile(128,lang.selectFile,"/",progPath,{"jsn"},programChanged,formView) 
                    end),{label=lang.openProg,font=FONT_BOLD})

        -- new program
        form.addRow(2)
        form.addIcon(":file",{width=30, enabled = false})
        form.addLink((function()
                        newProgram()
                    end),{label=lang.newProg,font=FONT_BOLD})
        
        -- delete program
        form.addRow(2)
        form.addIcon(":cross",{width=30, enabled = false})
        form.addLink((function()
                        saveProgram()
                        openfile.openfile(128,lang.selectFile,progPath,progPath,{"jsn"},deleteProgram,formView) 
                    end),{label=lang.deleteProg,font=FONT_BOLD})
        
        -- spacer
        form.addLabel({label="",font=FONT_MINI})
        
        -- program name
        form.addRow(2)
        form.addLabel({label=lang.progName})
        form.addTextbox(openfile.getFileName(program.name) or program.name,20,nameChanged)

        -- start switch
        form.addRow(2)
        form.addLabel({label=lang.startSwitch})
        form.addInputbox(startSwitch,true,startSwitchChanged)

        -- cancel switch
        form.addRow(2)
        form.addLabel({label=lang.cancelSwitch})
        form.addInputbox(cancelSwitch,true,cancelSwitchChanged)

        -- program procedure
        form.addRow(2)
        form.addLabel({label=lang.procedure}) form.addSelectbox({lang.auto,lang.singleStep,lang.teachInTime},program.procedure,false,procedureChanged)

        -- background music
        form.addRow(2)
        form.addLabel({label=lang.backgroundMusic})
        form.addLink((function()
                        editProgIndex = 0
                        openfile.openfile(128,lang.selectAudio,"/",audioPath,{"mp3"},audioChanged,subform) 
                    end),{label = openfile.getFileName(program.backgroundMusic) or program.backgroundMusic, alignRight=true})
        
        -- spacer
        form.addLabel({label="",font=FONT_MINI})
        
        -- program label
        form.addLabel({label=lang.program,font=FONT_BOLD})

        -- program list
        startIndex = 11
        for i, v in ipairs(program.prog) do
            if(type(v)=="string")then
                form.addRow(2)
                form.addLabel({label=lang.voiceOutput})
                form.addLink((function() 
                                    editProgIndex = i 
                                    openfile.openfile(128,lang.selectAudio,"/",audioPath,{"wav","mp3"},audioChanged,subform)
                                end),{label = openfile.getFileName(program.prog[i]) or program.prog[i], alignRight=true})
            elseif(type(v)=="number")then
                form.addRow(2)
                form.addLabel({label=lang.waitingTime})
                form.addIntbox(program.prog[i],10,18000,0,1,1, function(value) program.prog[i]=value end)
            end
        end

        form.addRow(1)
        form.addLabel({label="Powered by M.Lehmann V"..appVersion.." ",font=FONT_MINI,alignRight=true})
    end     
    
    -- get subform id from filebox and put it to application menu flow control
    formView = openfile.getSubformID() or subform
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
                system.playFile(program.backgroundMusic, AUDIO_BACKGROUND)
            end
            progRun=1
        end
    end
    if(cancelVal)then
        if(cancelVal>0.5) then
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
    program=tablecopy(new_program)
    program.name=system.pLoad("program","new")
    readProgram()
    startSwitch = system.pLoad("startSwitch")
    cancelSwitch = system.pLoad("cancelSwitch")
    system.registerForm(1,MENU_APPS,lang.appName,initForm,keyForm)
end

----------------------------------------------------------------------
setLanguage()
return {init=init,loop=loop,author="M.Lehmann",version=appVersion,name=lang.appName}
