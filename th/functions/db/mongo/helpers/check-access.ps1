function check_atlas_access {
    $status = & tsh status 2>$null
    $has_atlas_access = if ($status -match "atlas-read-only") { "true" } else { "false" }
    
    $json_output = & tsh db ls --format=json 2>$null
    
    return @{
        has_atlas_access = $has_atlas_access
        json_output = $json_output
    }
}