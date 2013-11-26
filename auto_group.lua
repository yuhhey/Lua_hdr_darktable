dt = require "darktable"

local function parse_datetime(d)
   local year
   year = string.sub(d, 1, 4)
   month = string.sub(d, 6, 7)
   day = string.sub(d, 9, 10)
   hour = string.sub(d, 12, 13)
   min = string.sub(d, 15, 16)
   sec = string.sub(d, 18, 19)
   return os.time{year=year, month=month, day=day, hour=hour, min=min, sec=sec} 
end

local function get_time_pair(image)
  kezdo = parse_datetime(image.exif_datetime_taken)
  veg = kezdo + image.exif_exposure
  return kezdo, veg
end


local function within_timediff(img1, img2, maxdiff)
  img1_beg, img1_end = get_time_pair(img1)
  img2_beg, img2_end = get_time_pair(img2)
  if (img2_beg-img1_end) < maxdiff then
    return true
  end
  return false
end

--[[
AEBChecker = {}
    def __init__(self):
        self.reset()
            
    def reset(self):
        self.ebvs = list()
       
    def __call__(self, comp_img, s_img):
        
        if 2 != s_img['Exif.Photo.ExposureMode']:
            return false
        ebv = s_img['Exif.Photo.ExposureBiasValue']
        if len(self.ebvs) != 0:
            #ebv = comp_img[key][Sequence.METADATA]['Exif.Photo.ExposureBiasValue'].value
            if ebv in self.ebvs:
                return false
        
        self.ebvs.append(ebv)
        return true
--]]

-- HDR processing starts here

local function group_images(img_list)

  elso_kep = img_list[1]
  for _, image in pairs(img_list) do
    image.group_with(image,elso_kep)
  end
  elso_kep.make_group_leader(elso_kep)
end

-- This function assumes that the images are ordered by exif time
local function group_sequences_in_selection_callback()
  dt.print_error("Indulunk")
  local img_list
  local hdr_list = {}
  local n_imgs = 0
  img_list = dt.gui.selection()
  elozo_kep = img_list[1]
  for _, image in pairs(img_list) do
    if within_timediff(elozo_kep, image, 7) then
      n_imgs = n_imgs + 1
      hdr_list[n_imgs] = image
    else
      if n_imgs > 1 then
        group_images(hdr_list)
      end
      hdr_list = {}
      n_imgs = 1
      hdr_list[n_imgs] = image
    end
    elozo_kep = image
  end
end
