resource "azurerm_cdn_frontdoor_profile" "frontdoor_profile" {
  name                = "${var.frontdoor_prefix}-profile"
  resource_group_name = module.resource_group[var.primary_region].name
  sku_name            = "Premium_AzureFrontDoor"

  response_timeout_seconds = 120

}

resource "azurerm_cdn_frontdoor_origin_group" "frontdoor_origin_group" {
  name                     = "${var.frontdoor_prefix}-origin-group"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.frontdoor_profile.id
  session_affinity_enabled = false

  restore_traffic_time_to_healed_or_new_endpoint_in_minutes = 10

  health_probe {
    interval_in_seconds = 100
    path                = "/"
    protocol            = "Https"
    request_type        = "HEAD"
  }

  load_balancing {
    additional_latency_in_milliseconds = 0
    sample_size                        = 16
    successful_samples_required        = 3
  }
}

resource "azurerm_cdn_frontdoor_endpoint" "frontdoor_endpoint" {
  name                     = "${var.frontdoor_prefix}-endpoint"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.frontdoor_profile.id
  enabled                  = true
}

resource "azurerm_cdn_frontdoor_origin" "frontdoor_origin" {
  for_each                      = local.locations
  name                          = "${var.frontdoor_prefix}-origin-${each.key}"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.frontdoor_origin_group.id
  enabled                       = true

  certificate_name_check_enabled = true # Required for Private Link
  host_name                      = module.web_app_service[each.key].resource_uri
  origin_host_header             = module.web_app_service[each.key].resource_uri
  priority                       = each.key == var.primary_region ? 1 : 2

  # private_link {
  #   request_message        = "Request access for CDN Frontdoor Private Link Origin Linux Web App Example"
  #   target_type            = "sites"
  #   location               = each.key
  #   private_link_target_id = module.web_app_service[each.key].resource_id
  # }
}

resource "azurerm_cdn_frontdoor_route" "frontdoor_route" {
  name                          = "${var.frontdoor_prefix}-route"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.frontdoor_endpoint.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.frontdoor_origin_group.id
  cdn_frontdoor_origin_ids      = [for origin in azurerm_cdn_frontdoor_origin.frontdoor_origin : origin.id]
  enabled                       = true

  forwarding_protocol    = "HttpsOnly"
  https_redirect_enabled = true
  patterns_to_match      = ["/*"]
  supported_protocols    = ["Http", "Https"]
}
