locals {

  spoke_vpc_count = length(var.spoke_vpc_cidr)

  indexes = slice(["a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l"], 0, local.spoke_vpc_count)

  spoke_vpc = {
    for spoke in var.spoke_vpc_cidr :
    "${local.indexes[index(var.spoke_vpc_cidr, spoke)]}" => {
      "cidr" = spoke
      "blackhole_routes" = {
        for combination in setproduct([local.indexes[index(var.spoke_vpc_cidr, spoke)]], compact([for x in local.indexes : x == local.indexes[index(var.spoke_vpc_cidr, spoke)] ? "" : x])) :
        "${combination[0]}${combination[1]}" => {
          "source"      = spoke
          "destination" = var.spoke_vpc_cidr[index(local.indexes, combination[1])]
        }
      }
    }
  }

  blackhole_routes = [
    flatten([for spoke, value in local.spoke_vpc :
      flatten([for combination, route in value["blackhole_routes"] :
        [
          {
            "route"       = combination
            "attachment"  = substr(combination, 0, 1)
            "destination" = route["destination"]
          }
      ]])
    ])
  ][0]
}
