dt = require "darktable"


local function copy_exif_data(from_img, to_img)
  to_img.exif_maker = from_img.exif_maker
  to_img.exif_datetime_taken = from_img.exif_datetime_taken
end

local function addTag(tag_str, img)
  tag = dt.tags.create(tag_str)
  dt.tags.attach(tag, img)
end

local function add_HDR_to_group(image, filename)
  imported_img = dt.database.import(filename)
  -- copy_exif_data(image, imported_img)
  image.group_with(imported_img, image)
  -- imported_img.make_group_leader(imported_img)
  

end


local function parse_datetime(d)
   local year = string.sub(d, 1, 4)
   local month = string.sub(d, 6, 7)
   local da = string.sub(d, 9, 10)
   local hour = string.sub(d, 12, 13)
   local min = string.sub(d, 15, 16)
   local sec = string.sub(d, 18, 19)
   return os.time{year=year, month=month, day=da, hour=hour, min=min, sec=sec} 
end


local function getStartAndEndOfShot(image)
  kezdo = parse_datetime(image.exif_datetime_taken)
  veg = kezdo + image.exif_exposure
  return kezdo, veg
end


local function isWithinTimediff(img1, img2, maxdiff)
  _, img1_end = getStartAndEndOfShot(img1)
  img2_beg, _ = getStartAndEndOfShot(img2)
  
  if (img2_beg-img1_end) < maxdiff then
    return true
  end
  
  return false
end

local function group_images(img_list)
  print("group_images", img_list)
  local elso_kep = img_list[1]
  for _, image in pairs(img_list) do
    image.group_with(image,elso_kep)
  end
  elso_kep.make_group_leader(elso_kep)
end

local function tag_images(img_list, tag_str)
  for _, img in pairs(img_list) do
    addTag(tag_str, img)
  end
end

local function process_hdr_list(hdrlist, n_imgs)
  if n_imgs > 1 then
    group_images(hdrlist)
    tag_images(hdrlist, "HDR_nyersanyag")
  end
end

-- This function assumes that the images are ordered by exif time
local function group_sequences_in_selection_callback()
  dt.print_error("Indulunk")
  local img_list
  local hdr_list = {}
  local n_imgs = 0
  local maxdiff
  maxdiff = dt.preferences.read("group_sequences_in_selection", "max_diff", "integer")
  img_list = dt.gui.selection()
  elozo_kep = img_list[1]
  for _, image in pairs(img_list) do
    print(elozo_kep.filename, n_imgs )
    print(image.filename, n_imgs)
    if elozo_kep.is_raw and image.is_raw then
      if isWithinTimediff(elozo_kep, image, maxdiff) then
        n_imgs = n_imgs + 1
        hdr_list[n_imgs] = image
      else
        process_hdr_list(hdr_list, n_imgs)
        hdr_list = {}
        n_imgs = 1
        hdr_list[n_imgs] = image
      end
    end
    elozo_kep = image
  end
  process_hdr_list(hdr_list, n_imgs)
  dt.print_error("Végeztünk")
end

local function keepIntermediateFiles()
  dt.print_error(tostring(dt.preferences.read("genHDR", "keep_intermediate_file", "bool")))
  return dt.preferences.read("genHDR", "keep_intermediate_file", "bool")
end

local function buildHDRPrefix(fn_list, target_path)
  local hdr_prefix=''
  for _,fn in pairs(fn_list) do
    hdr_prefix = hdr_prefix..fn.sub(fn, string.find(fn, '%d%d%d%d'))..'_'
  end
  hdr_postfix = dt.preferences.read("generateHDR", 
			"hdr_postfix",
									"string")
  return target_path..'/'..hdr_prefix..hdr_postfix
end

local function append_filelist(cmd, fnlist)
  dt.print_error(cmd)
  for _, fn in pairs(fnlist) do
    cmd = cmd.." "..fn
  end
  return cmd
end

local function execute(cmd)
  dt.print_error(cmd)
  os.execute(cmd)
end

local function executeEnfuse(output_fn, input_prefix)
  execute("enfuse-mp --no-ciecam -o "..output_fn..' '..input_prefix..'*')
end

local function executeAlignImageStack(tmp_prefix, pto_file, fn_list)
  align_image_stack_cmd = "align_image_stack -a "..tmp_prefix.." -p "..pto_file
  align_image_stack_cmd = append_filelist(align_image_stack_cmd, fn_list)
  execute(align_image_stack_cmd)
end

local function getValidFilename(fnlist)  
  for _, fn in pairs(fnlist) do
    dt.print_error(tostring(i))
    if fn ~= nil then
      return fn
    end
  end
  return nil
end

-- HDR processing starts here
-- fn_list: full path input filenames
-- target_path: full path of the generated image
local function generateHDR(fn_list, target_path)


  local hdr_prefix = buildHDRPrefix(fn_list, target_path)
  local pto_file = hdr_prefix..'.pto'
  local output_fn = hdr_prefix..'.tif'
  local tmp_prefix = hdr_prefix.."_AIS_"

  executeAlignImageStack(tmp_prefix, pto_file, fn_list)

  executeEnfuse(output_fn, tmp_prefix)
  
  local f = getValidFilename(fn_list)
  execute("exiftool -overwrite_original -tagsfromfile "..f.." "..output_fn)

  if not keepIntermediateFiles() then
    rm_cmd = "rm "..tmp_prefix..'*'
    execute(rm_cmd)
  end
  
  if not keepIntermediateFiles() then
    rm_cmd = append_filelist("rm ", fn_list)
    execute(rm_cmd)
  end
  return output_fn
end

local function create_hdr_prefix(target_path, fn_list)
  local hdr_prefix =''
  
  for _,fn in pairs(fn_list) do
    hdr_prefix = hdr_prefix..fn.sub(fn, string.find(fn, '%d%d%d%d'))..'_'
    print(pto_file)
  end
  
  hdr_prefix = target_path..'/'..hdr_prefix..'hdr'
  return hdr_prefix
end

local function get_last_dot(path)
  local i = 0

  while(i) do
    f = i
    i = path:find('%.', i+1)
  end
  
  return f
end

local function dotIsTheLastCharacter(path)
  return (get_last_dot(path) == path:len())
end

local function getExtension(img_fn)
  ld = get_last_dot(img_fn)
  extension = img_fn:sub(ld+1, img_fn:len())
  return extension
end

local function Issue_9706_workaround(exported_fn, img_fn)
  if dotIsTheLastCharacter(exported_fn) then   
    return exported_fn..getExtension(img_fn)
  else
    return exported_fn
  end
end


--[[ We need this function because the image object used as the index 
     of the exported_img_list of export finalize callback  is not equal to
     to images returned by dt_lua_img_t.get_group_members.
     Bug report: http://darktable.org/redmine/issues/9698
--]]

local function lookup_the_right_image_object(img, list_of_images)
  local image, fn

  for image, fn in pairs(list_of_images) do
    if img == image then
      return image
    end
  end
  return nil
end

local function isExported(img)
  return img ~= nil
end

local function isRejected(img)
  return img.rating == -1
end


local function buildExportedImgFnTable(imgs, exported_img_list)
  local n_fns = 0
  local exported_fn_table = {}
  
  for i, img in ipairs(imgs) do
    dt.print_error("i = "..tostring(i))
    good_img = lookup_the_right_image_object(img, exported_img_list)
    if isExported(good_img) and not isRejected(good_img) then
      exported_fn_table[i] = Issue_9706_workaround(exported_img_list[good_img],
                                                   img.filename)
      dt.print_error(i..tostring(img)..','..exported_fn_table[i])
	  n_fns = n_fns + 1
    end
  end
  return n_fns, exported_fn_table
end

local function isGroupLeader(img)
  return img == img.group_leader
end


local function generateMakefile(img_list)

  writeRules()
  writeVariables()

  for image in img_list do
    if image.is_raw and isGroupLeader(image) then
      imgs = image.get_group_members(image)
      writeDependency(imgs)
    end
  end
end

local function export_hdr_finalize_callback(storage, exported_img_list)
  dt.print_error("Export finished, postprocessing starts.")

  for image, tmp_fn in pairs(exported_img_list) do
    if image.is_raw and isGroupLeader(image) then
      imgs = image.get_group_members(image)
      n_fns, exported_fn_table = buildExportedImgFnTable(imgs,
                                                         exported_img_list)
      dt.print_error(tostring(exported_fn_table))
      if n_fns > 1 then
	    hdr_fajl = generateHDR(exported_fn_table, image.path)
	    if hdr_fajl ~= nil then
	      print("Uj leader: ", hdr_fajl)
	      add_HDR_to_group(image, hdr_fajl)
	    end
      end
    else
      print("Nem leader vagy nem raw", image.filename)
    end
  end
  dt.print_error("Ennyi volt!")
end


local function generateHDRFromSingleImg(img)
  img_list = createDuplicates(img)
  
  n_fns, exported_fn_table = buildExportedImgFnTable(img_list)
  generateHDR(exported_fn_table, img.path)  
end

dt.preferences.register("generateHDR", 
						"hdr_postfix",
						"string",
						"HDR postfix",
						"Postfix of HDR images generated from groups",
						"hdr")

dt.preferences.register("group_sequences_in_selection",
						"max_diff",
						"integer",
						"Max difference in image sequences",
						"Max time difference to consider subsequent images as part of the same sequence ",
						7,
						1,
						100)
						
dt.preferences.register("genHDR",
						"keep_intermediate_file",
						"bool",
						"Keep the exported intermediate files",
						"Does not delete the exported files in ~/.local/tmp if checked",
						false)

dt.register_event("shortcut",
                  group_sequences_in_selection_callback,
                  "group HDR sequences in selection")



dt.register_storage("Generate HDR",
		            "generate HDR",
                    nil,
                    export_hdr_finalize_callback)

