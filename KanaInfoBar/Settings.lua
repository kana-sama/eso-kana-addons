local A,M=KanaInfoBar,KanaInfoBar.Model

function A:OpenSettings()
    if self.edit then self:CloseEditor(false) end
    LibAddonMenu2:OpenToPanel(self.settingsPanel)
end

function A:InitializeSettings()
    local panelName='KanaInfoBarSettings'
    self.settingsPanel=LibAddonMenu2:RegisterAddonPanel(panelName,{
        type='panel',name='KanaInfoBar',displayName='KanaInfoBar',author='Kana',version='1.0.12',
        registerForRefresh=true,registerForDefaults=false,
    })
    local options={
        {type='description',text='Иконки и значения без фона. Перетаскивай виджеты между строками в редакторе.\nЯкорь определяет направление роста панели и выравнивание строк.'},
        {type='checkbox',name='Показывать панель',getFunc=function() return self.sv.shown end,
            setFunc=function(v) self.sv.shown=v; self:Refresh(true) end},
        {type='checkbox',name='Grid mode',tooltip='Выравнивать виджеты разных строк по общим столбцам. Короткие строки размещаются по выбранному якорю.',
            getFunc=function() return self.sv.gridMode end,
            setFunc=function(v) self.sv.gridMode=v; self:Refresh(true) end},
        {type='button',name='Редактировать панель',tooltip='Перемещение панели, виджетов и создание строк. Нулевые показатели тоже будут доступны.',
            func=function() self:OpenEditor() end,width='full'},
        {type='dropdown',name='Якорь',choices=M.anchorNames,choicesValues=M.anchorOrder,
            tooltip='Неподвижная точка самой панели при изменении её размера. Смена якоря не перемещает панель.',
            getFunc=function() return self.sv.anchor end,setFunc=function(v) self:SetAnchorChoice(v) end},
        {type='slider',name='Масштаб',min=75,max=150,step=5,
            getFunc=function() return self.sv.scale*100 end,
            setFunc=function(v) self.sv.scale=v/100; self:Refresh(true) end},
        {type='slider',name='Расстояние между виджетами',min=4,max=24,step=1,
            getFunc=function() return self.sv.gap end,setFunc=function(v) self.sv.gap=v; self:Refresh(true) end},
        {type='slider',name='Расстояние между строками',min=0,max=16,step=1,
            getFunc=function() return self.sv.rowGap end,setFunc=function(v) self.sv.rowGap=v; self:Refresh(true) end},
        {type='header',name='Виджеты'},
    }
    for _,id in ipairs(self.ids) do
        local module=self.modules[id]
        options[#options+1]={type='checkbox',name=module.name,
            getFunc=function() return self.sv.enabled[id] end,
            setFunc=function(v) self.sv.enabled[id]=v; self:Refresh(true) end,
            tooltip=function()
                if id=='messages' then return 'Сообщения AetherChat, непрочитанная почта и уведомления ESO. Каждый значок скрывается при нуле; весь виджет скрывается, когда все счётчики равны нулю.' end
                if id=='dps' then return CMX and 'Свой DPS из Combat Metrics; доля группового DPS показывается только в группе.' or 'Combat Metrics не загружен; вместо данных будет прочерк.' end
                if id=='treasure' then return 'Только краденые сокровища. При отсутствии скрывается; клик открывает все краденые вещи.' end
                if id=='durability' then return 'Минимальная прочность надетого снаряжения. Оранжевый при 20% и ниже, красный при поломке.' end
                return 'Положение внутри панели меняется перетаскиванием в редакторе.'
            end,
        }
    end
    LibAddonMenu2:RegisterOptionControls(panelName,options)
end
