using System.ComponentModel.DataAnnotations;

namespace SmartAgri.Api.DTOs;

public sealed class CartItemRequest
{
    [Range(1, int.MaxValue)]
    public int ProductId { get; set; }

    [Range(1, int.MaxValue)]
    public int Quantity { get; set; }
}

public sealed class CartQuantityRequest
{
    [Range(1, int.MaxValue)]
    public int Quantity { get; set; }
}