dt = require "darktable"
os = require "os"

local function HDR_from_group(image)
	local imgs
	imgs = image.get_group_members(image)
	hdr_img_path = HDR_from_image_table(imgs, image.path)

	-- Import the HDR, add to the selection and set it as the group leader
	imported_img = dt.database.import(hdr_img_path)
	dt.print_error(imported_img.filename)
	image.group_with(imported_img, image)
	image.make_group_leader(imported_img)
end

local function HDR_from_image_table(img_table, target_path)

	local tmp_prefix = image.path.."/".."dt_hdr_tmp"
	local fn_list = {}

	for i, img in ipairs(img_table) do
		fn_list[i] = img.path.."/"..img.filename
	end

	return generateHDR(fn_list, target_path)
end

-- fn_list: full path filenames
-- target_path: full path of the generated image
local function generateHDR(fn_list, target_path)

	local tmp_path = '/tmp'
	local tmp_prefix = tmp_path.."/".."dt_hdr_tmp"
	local pto_file, fn

	fn = fn_list[1]
	print(fn)
	pto_file = fn.sub(fn, 1, string.find(fn, '.', 1, true)).."pto"

	-- Build align_image_stack command
	align_image_stack_cmd = "align_image_stack -a "..tmp_prefix.." -p "..pto_file
	for i, img in ipairs(fn_list) do
		align_image_stack_cmd = align_image_stack_cmd.." "..img
	end
	dt.print_error(align_image_stack_cmd)
	os.execute(align_image_stack_cmd)

	-- Create the final image with enfuse
	dot_helye = string.find(fn, '.', 1, true)
	dt.print_error(dot_helye..fn)
	output_fn = fn.sub(fn, dot_helye-4, dot_helye-1)
	enfuse_cmd = "enfuse -o "..target_path..' '..tmp_prefix..'*'
	dt.print_error(enfuse_cmd)
	os.execute(enfuse_cmd)

	-- Finally we delete the temporary files
	rm_cmd = "rm "..tmp_prefix..'*'
	dt.print_error(rm_cmd)
	os.execute(rm_cmd)

	return target_path
end

local function generate_hdr_from_table(img_table)

	for i, image in pairs(img_table) do
		if image.is_raw then
			if image == image.group_leader then
				-- TODO: a target path-t még meg kell csinálni.
				generateHDR(image)
			end
		else
			dt.print_error(image.filename.." is raw. Skipping...")
		end
	end
end

--[[ We need this function because the image object used as the index 
     of the exported_img_list of export finalize callback  is not equal to
     to images returned by dt_lua_img_t.get_group_members.
     Probably it is a bug to be reported.
--]]
local function lookup_the_right_image_object(img, exported_images)
  local image, fn

  for image, fn in pairs(exported_images) do
    if img == image then
      return image
    end
  end
  return nil
end

function export_hdr_callback(storage, exported_img_list)
	local exported_fn_table = {}

	dt.print_error("Export finished, postprocessing starts.")

	for image, tmp_fn in pairs(exported_img_list) do
		if image.is_raw and (image == image.group_leader) then
			imgs = image.get_group_members(image)
			local n_fns = 0
			for i, img in ipairs(imgs) do
				good_img = lookup_the_right_image_object(img, exported_img_list)
				exported_fn_table[i] = exported_img_list[good_img]
				dt.print_error(i..tostring(img)..','..exported_fn_table[i])
				n_fns = n_fns + 1
			end
			dt.print_error(tostring(exported_fn_table))
			if n_fns > 1 then
				hdr_fajl = generateHDR(exported_fn_table, image.path..image.filename.."_HDR.tif")
				if hdr_fajl then
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