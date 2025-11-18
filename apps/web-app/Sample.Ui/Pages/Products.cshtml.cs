using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Sample.Ui.Services;

namespace Sample.Ui.Pages
{
    public class ProductsModel : PageModel
    {
        private readonly IProductService _productService;
        private readonly ILogger<ProductsModel> _logger;

        public List<Product>? Products { get; set; }
        public string? ErrorMessage { get; set; }

        public ProductsModel(IProductService productService, ILogger<ProductsModel> logger)
        {
            _productService = productService;
            _logger = logger;
        }

        public async Task OnGetAsync()
        {
            try
            {
                var result = await _productService.GetProducts();
                if(result.Success)
                {
                    Products = result.Products ?? new List<Product>(); 
                    _logger.LogInformation($"Successfully retrieved {Products.Count} products");
                }
                else
                {
                    ErrorMessage = $"Failed to retrieve products: {result.ErrorMessage}";
                    _logger.LogError($"Failed to retrieve products: {result.ErrorMessage}");
                    Products = new List<Product>();
                }
            }
            catch (Exception ex)
            {
                ErrorMessage = $"An error occurred: {ex.Message}";
                _logger.LogError(ex, "Exception occurred while retrieving products");
                Products = new List<Product>();
            }
        }
    }
}
