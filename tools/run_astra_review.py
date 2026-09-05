#!/usr/bin/env python3
"""Run source-only upstream checks, or historical Astra checks with local fixtures."""
import argparse, json, os, subprocess, sys
from pathlib import Path
CORE = ['stadium_circle_depth_test.lua', 'stadium_background_api_test.lua', 'stadium_models_api_test.lua', 'battle_scene_visual_sidecar_test.lua', 'battle_ui_visibility_test.lua', 'choose_your_hero_test.lua', 'hosted_trainer_visibility_test.lua', 'renderer_orientation.lua', 'voxel_build_budget_test.lua', 'test46_legendary_world_props.lua', 'test47_city_supported_sapling.lua', 'test48_select_camera_cycle.lua', 'test49_select_camera_crash_fix.lua']
FULL = ['astra_full_pass_seats_test.lua', 'astra_full_round_table_test.lua', 'astra_full_round_table_placement_test.lua', 'astra_beach_house_test.lua', 'astra_cable_club_stool_test.lua', 'astra_lab_desk_geometry_test.lua', 'astra_lab_desk_placement_test.lua', 'astra_lab_stool_geometry_test.lua', 'astra_lab_stool_placement_test.lua', 'astra_bill_pipe_geometry_test.lua', 'astra_bill_pipe_placement_test.lua', 'astra_upright_case_test.lua', 'astra_computer_case_test.lua', 'astra_computer_placement_test.lua', 'astra_bill_machine_geometry_test.lua', 'astra_bill_machine_placement_test.lua', 'astra_bills_chair_test.lua', 'astra_bills_chair_placement_test.lua', 'astra_round_stool_symmetry_test.lua', 'astra_table_geometry_test.lua', 'astra_table_placement_test.lua', 'astra_square_stool_centering_test.lua', 'astra_square_stool_rim_test.lua', 'astra_square_stool_rear_test.lua', 'astra_furniture_support_test.lua', 'astra_ship_stool_projection_test.lua', 'astra_ship_stool_integration_test.lua', 'astra_ship_unchanged_models_test.lua', 'astra_building_contact_test.lua', 'astra_build_budget_test.lua', 'building_facade_culling_test.lua', 'voxel_mesh_disk_storage_test.lua', 'astra_terrain_shading_test.lua', 'building_canopy_regression_test.lua', 'voxel_seam_ao_test.lua', 'legendary_visuals_test.lua', 'astra_interior_stairs_test.lua', 'astra_cave_ladder_geometry_test.lua', 'astra_cave_ladder_placement_test.lua', 'astra_oak_furniture_test.lua', 'astra_red_house_geometry_test.lua', 'astra_oak_item_contact_test.lua', 'astra_red_house_placement_test.lua', 'astra_public_stairs_test.lua', 'astra_workbench_geometry_test.lua', 'astra_workbench_placement_test.lua', 'astra_facility_palm_geometry_test.lua', 'astra_facility_palm_placement_test.lua', 'astra_facility_cabinet_geometry_test.lua', 'astra_facility_cabinet_placement_test.lua', 'astra_cave_steps_geometry_test.lua', 'astra_cave_steps_support_test.lua', 'astra_ship_hull_geometry_test.lua', 'astra_ship_hull_placement_test.lua', 'astra_ship_hull_cache_test.lua', 'astra_remaining_ship_geometry_test.lua', 'astra_remaining_interiors_placement_test.lua', 'astra_bicycle_geometry_test.lua', 'astra_bicycle_placement_test.lua']
FULL.extend(['astra_cabin_details_test.lua', 'astra_cave_exit_visuals_test.lua', 'astra_facade_entrances_test.lua', 'astra_hanging_scrolls_test.lua', 'astra_rear_walls_test.lua'])
ENGINE_TESTS = {"building_canopy_regression_test.lua", "voxel_seam_ao_test.lua", "legendary_visuals_test.lua"}
def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fixtures", type=Path, help="JSON of ASTRA_* fixture paths; enables full audit")
    parser.add_argument("--luajit", default="luajit")
    parser.add_argument("--output", type=Path, help="optional JSON receipt")
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[1]
    env = os.environ.copy()
    # Prevent another checkout's candidate overrides from contaminating this run.
    for key in list(env):
        if key.startswith("ASTRA_"): del env[key]
    config = json.loads(args.fixtures.read_text()) if args.fixtures else {}
    env.update({key: str(value) for key, value in config.items()})
    tests = CORE + (FULL if args.fixtures else [])
    results = []
    for name in tests:
        test_env = env.copy()
        cwd = repo
        command = [args.luajit, "tests/" + name]
        if name in ENGINE_TESTS:
            cwd = Path(config["ASTRA_ENGINE"]).resolve()
            test_env["DS_MOD_PATH"] = os.path.relpath(repo, cwd).replace("\\", "/")
            command = [args.luajit, str(repo / "tests" / name)]
            if name != "building_canopy_regression_test.lua":
                command.insert(1, str(repo / "tests/astra_windows_runner.lua"))
        if name == "astra_terrain_shading_test.lua" and args.fixtures:
            test_env["ASTRA_BASELINE"] = config["ASTRA_CURRENT_UPSTREAM"]
        if name == "astra_ship_stool_integration_test.lua":
            test_env["ASTRA_SHIP_BASELINE"] = config["ASTRA_SHIP_STOOL_BASELINE"]
        run = subprocess.run(command, cwd=cwd, env=test_env, capture_output=True, text=True, encoding="utf-8")
        output = run.stdout + run.stderr
        print(("PASS " if run.returncode == 0 else "FAIL ") + name)
        if run.returncode: print(output)
        results.append({"test": name, "exit_code": run.returncode, "output": output})
    files = [repo / "main.lua"] + sorted((repo / "lib").rglob("*.lua")) + sorted((repo / "data").rglob("*.lua"))
    source = "\n".join("assert(loadfile(" + json.dumps(f.as_posix()) + "))" for f in files)
    compiled = subprocess.run([args.luajit, "-"], input=source, cwd=repo, text=True, capture_output=True)
    receipt = {"results": results, "production_lua_files": len(files), "compile_exit_code": compiled.returncode}
    if args.output: args.output.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print(str(sum(x["exit_code"] == 0 for x in results)) + "/" + str(len(results)) + " commands passed; " + str(len(files)) + " Lua files checked")
    return int(compiled.returncode != 0 or any(x["exit_code"] for x in results))
if __name__ == "__main__": sys.exit(main())
