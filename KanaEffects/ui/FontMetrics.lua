-- Cold geometry cache, bounded across arbitrary positive fractional font sizes.
local FontMetrics = {}
KanaEffects.FontMetrics = FontMetrics
local MAX_DESCRIPTORS = 4
local MAX_TEXTS = 1200
function FontMetrics.New(controls)
    return setmetatable({controls=controls, cache={}, order={}}, {__index=FontMetrics})
end
function FontMetrics:MeasureText(text, size, role)
    assert(not self.disposed, 'font metrics disposed')
    local scale = self.controls:Scale()
    if self.scale ~= scale then self.cache={}; self.order={}; self.scale=scale end
    local descriptor = self.controls:FontDescriptor(size,role)
    local key=role..':'..descriptor
    local bucket=self.cache[key]
    if not bucket then
        if #self.order == MAX_DESCRIPTORS then self.cache[table.remove(self.order,1)]=nil end
        bucket={values={},order={}}; self.cache[key]=bucket; self.order[#self.order+1]=key
    end
    local metrics=bucket.values[text]
    if not metrics then
        local width,height=self.controls:MeasureText(text,descriptor)
        if #bucket.order == MAX_TEXTS then bucket.values[table.remove(bucket.order,1)]=nil end
        metrics={width,height}; bucket.values[text]=metrics; bucket.order[#bucket.order+1]=text
    end
    return metrics[1],metrics[2]
end
function FontMetrics:TargetCaptionHeight()
    assert(not self.disposed, 'font metrics disposed')
    return self.controls:FontHeight('ZoFontGameShadow')
end
function FontMetrics:Dispose() self.disposed=true; self.cache={}; self.order={} end
