GUIFunctions.AddTab("Inventory View")

global g_InventoryView := new IC_InventoryView_Component
global g_InventoryViewChestsCheckbox
global g_InventoryViewBuffsCheckbox

; Add GUI fields to this addon's tab.
Gui, ICScriptHub:Tab, Inventory View
Gui, ICScriptHub:Font, w700
Gui, ICScriptHub:Add, Text, x15 y+15, Inventory:
Gui, ICScriptHub:Font, w400

Gui, ICScriptHub:Add, Button, x+15 yp+0 w60 vButtonReadInventory, Load
buttonFunc := ObjBindMethod(g_InventoryView, "ReadCombinedInventory")
GuiControl,ICScriptHub: +g, ButtonReadInventory, % buttonFunc

Gui, ICScriptHub:Add, Button, x+15 yp+0 w75 vButtonResetInventory, Reset
buttonFunc := ObjBindMethod(g_InventoryView, "ResetInventory")
GuiControl,ICScriptHub: +g, ButtonResetInventory, % buttonFunc

Gui, ICScriptHub:Add, Checkbox, vg_InventoryViewChestsCheckbox x+15 yp+3, Chests
Gui, ICScriptHub:Add, Checkbox, vg_InventoryViewBuffsCheckbox x+15, Buffs
buttonFunc := ObjBindMethod(g_InventoryView, "SaveSettings")
GuiControl,ICScriptHub: +g, g_InventoryViewChestsCheckbox, % buttonFunc
GuiControl,ICScriptHub: +g, g_InventoryViewBuffsCheckbox, % buttonFunc
buttonFunc := ObjBindMethod(g_InventoryView, "LoadSettings")
buttonFunc.Call()

Gui, ICScriptHub:Add, Text, vInventoryViewTimeStampID x15 y+15 w455, % "Last Updated: "

GUIFunctions.UseThemeTextColor("TableTextColor")
Gui, ICScriptHub:Add, ListView, x15 y+5 w450 h450 vInventoryViewID, `ID|Name|Amount|Change|Per `Run
GUIFunctions.UseThemeListViewBackgroundColor("InventoryViewID")

; Highly recommended to use classes to reduce chance of interference with other addons/code.
; Below is the functionality included with the component. For readability in more complex addons, these will often be separated 
; into a new ahk file that is read from an #include line here.

; IC_InventoryVIew_Component uses the MemoryReads to keep track of non-chest Inventory changes.
class IC_InventoryView_Component
{
    FirstReadValues := ""
    ; ReadInventory reads the inventory from in game and displays it in a list. Remembers first run values to compare for changes and per run calculations.
    ReadInventory(runCount := 1, doAddToFirstRead := false)
    {  
        if(!IsObject(this.FirstReadBuffValues))
        {
            this.FirstReadBuffValues := {}
            doAddToFirstRead := true
        }
        size := g_SF.Memory.ReadInventoryItemsCount()
        loop, %size%
        {
            change := ""
            buffID := g_SF.Memory.ReadInventoryBuffIDBySlot(A_Index)
            itemName := g_SF.Memory.ReadInventoryBuffNameBySlot(A_Index)
            itemAmount := g_SF.Memory.ReadInventoryBuffCountBySlot(A_Index)
            if(doAddToFirstRead) ; only create first object if there is an inventory
                this.FirstReadBuffValues.Push({"ID":buffID, "Name":itemName, "Amount":itemAmount})
            change := this.GetChange(buffID, itemAmount, "Buff")
            perRunVal := Round(change / runCount, 2)
            if(!perRunVal)
                perRunVal := ""
            if(!change)
                change := ""
            LV_Add(,buffID,itemName, itemAmount, change, perRunVal)
        }
    }

    ; Resets inventory stats.
    ResetInventory()
    {
        this.FirstReadBuffValues := ""
        this.FirstReadChestValues := ""
        this.ReadCombinedInventory(1)
    }

    ; Loads settings from the addon's setting.json file.
    LoadSettings()
    {
        this.Settings := g_SF.LoadObjectFromJSON( A_LineFile . "\..\Settings.json")
        if(this.Settings == "")
        {
            this.Settings := {}
            this.Settings["LoadChests"] := True
            this.Settings["LoadBuffs"] := True
            this.SaveSettings()
        }
        if(this.Settings["LoadChests"] == "")
            this.Settings["LoadChests"] := True
        if(this.Settings["LoadBuffs"] == "")
            this.Settings["LoadBuffs"] := True
        GuiControl,ICScriptHub:, g_InventoryViewChestsCheckbox, % this.Settings["LoadChests"]
        GuiControl,ICScriptHub:, g_InventoryViewBuffsCheckbox, % this.Settings["LoadBuffs"]
        Gui, Submit, NoHide
    }
    
    ; Saves settings to addon's setting.json file.
    SaveSettings()
    {
        Gui, Submit, NoHide
        this.Settings["LoadChests"] := g_InventoryViewChestsCheckbox
        this.Settings["LoadBuffs"] := g_InventoryViewBuffsCheckbox
        g_SF.WriteObjectToJSON( A_LineFile . "\..\Settings.json", this.Settings )
    }

    ; Reads the game memory for all chests in the inventory and their counts and shows it in the inventory view.
    ReadChests(runCount := 1, doAddToFirstRead := false)
    {
        if(!IsObject(this.FirstReadChestValues) )
        {
            this.FirstReadChestValues := {}
            doAddToFirstRead := true
        }
        size := g_SF.Memory.ReadInventoryChestListSize()
        if(!size)
            return "" 
        loop, %size%
        {
            chestID := g_SF.Memory.GetInventoryChestIDBySlot(A_Index)
            itemAmount := g_SF.Memory.GetInventoryChestCountBySlot(A_Index)
            itemName := g_SF.Memory.GetChestNameByID(chestID)
            change := this.GetChange(chestID, itemAmount, "Chest")
            perRunVal := Round(change / runCount, 2)
            if(doAddToFirstRead) ; only create first object if there is an inventory
                this.FirstReadChestValues.Push({"ID":chestID, "Name":itemName, "Amount":itemAmount})
            if(!perRunVal)
                perRunVal := ""
            if(!change)
                change := ""
            LV_Add(, chestID, itemName, itemAmount, change, perRunVal)
        }
    }

    ; Reads inventory from memory and displays it in the ListView
    ReadCombinedInventory(runCount := 1)
    {
        restore_gui_on_return := GUIFunctions.LV_Scope("ICScriptHub", "InventoryViewID")
        doAddToFirstRead := false
        lastUpdateString := "Last Updated: " . A_YYYY . "/" A_MM "/" A_DD " at " A_Hour . ":" A_Min 
        if(WinExist("ahk_exe " . g_userSettings[ "ExeName"])) ; only update when the game is open
            g_SF.Memory.OpenProcessReader()
        else
            return
        LV_Delete()
        startTime := A_TickCount
        Gui, Submit, NoHide
        if(g_InventoryViewChestsCheckbox)
            this.ReadChests(runCount, doAddToFirstRead)
        if(g_InventoryViewBuffsCheckbox)
            this.ReadInventory(runCount, doAddToFirstRead)
        LV_ModifyCol()
        LV_ModifyCol(1, Integer)  
        LV_ModifyCol(3, Integer)
        LV_ModifyCol(4, 50 Integer)
        LV_ModifyCol(5, 50 Integer)
        timeToProcess := (A_TickCount - startTime) / 1000
        GuiControl, ICScriptHub:, InventoryViewTimeStampID, % lastUpdateString . " in " . timeToProcess . "s"
    }

    ; ClearFirstRead clears the first run values to start new tracking.
    ClearFirstRead()
    {
        this.FirstReadBuffValues := ""
        this.FirstReadChestValues := ""
    }

    ; GetChange compares the current inventory item's (buffID) value (itemAmount) with the start value and returns the difference.
    GetChange(itemID, itemAmount, itemType := "Buff")
    {
        firstCount := this.GetFirstCountFromID(itemID, itemType)
        diff := itemAmount - firstCount
        return diff
    }

    ; GetFirstCountFromID returns the inventory start amount for the item (buffID) passed in.
    GetFirstCountFromID(buffID, itemType := "Buff")
    {
        if (itemType == "Buff")
        {
            idValuePairs := this.FirstReadBuffValues
        }
        else if (itemType == "Chest")
        {
            idValuePairs := this.FirstReadChestValues
        }
        else
        {
            return ""
        }
        for k, v in idValuePairs
        {
            if(v["ID"] == buffID)
                return v["Amount"]
        }
        return ""
    }
}

#include %A_LineFile%\..\..\..\SharedFunctions\ObjRegisterActive.ahk