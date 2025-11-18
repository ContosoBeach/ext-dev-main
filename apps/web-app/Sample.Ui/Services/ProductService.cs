using Azure.Core;
using Azure.Identity;
using Microsoft.AspNetCore.Mvc;
using Newtonsoft.Json;
using System.Net.Http.Headers;

namespace Sample.Ui.Services
{
    public class ProductService : IProductService
    {
        private HttpClient _httpClient;
        private readonly IApiConfigService _apiConfigService;
        private readonly ILogger<ProductService> _logger;

        public ProductService(IApiConfigService apiConfigService, ILogger<ProductService> logger)
        {
            _apiConfigService = apiConfigService;
            _logger = logger;
            _httpClient = GetClient().Result;
        }

        private async Task<HttpClient> GetClient()
        {
            var apiUri = _apiConfigService.Get(ApiConfigType.ApiUri);
            var apiAuthUri = _apiConfigService.Get(ApiConfigType.ApiAuthUri);
            
            _logger.LogInformation($"API URI: {apiUri}");
            _logger.LogInformation($"API Auth URI: {apiAuthUri}");
            
            // The resource URI of the App Registration
            var jwt = string.Empty;
            if (!string.IsNullOrWhiteSpace(apiAuthUri))
            {
                try
                {
                    jwt = await GetTokenAsync(apiAuthUri);
                    _logger.LogInformation("Successfully obtained JWT token");
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Failed to obtain JWT token");
                }
            }
            else
            {
                _logger.LogInformation("No API Auth URI configured, proceeding without authentication");
            }
            
            var httpClient = new HttpClient()
            {
                BaseAddress = new Uri(apiUri)
            };

            if (!string.IsNullOrWhiteSpace(apiAuthUri) && !string.IsNullOrWhiteSpace(jwt))
            {
                // Add the JWT to the request headers as a bearer token (this is the default for the `validate-azure-ad-token` policy, but you could override it and use a different header)
                httpClient.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", jwt);
                _logger.LogInformation("Added JWT token to HTTP client headers");
            }

            return httpClient;
        }

        public static async Task<string> GetTokenAsync(string? targetAppUri)
        {
            // Use the built in ManagedIdentityCredential class to retrieve the managed identity, filtering on client ID if user assigned. We could also use the DefaultAzureCredential class to make debugging simpler.
            var msiCredentials = new ManagedIdentityCredential();

            // Use the GetTokenAsync method to generate a JWT for use in a HTTP request
            var accessToken = await msiCredentials.GetTokenAsync(new TokenRequestContext(new[] { $"{targetAppUri}/.default" }));
            var jwt = accessToken.Token;
            return jwt;
        }

        public async Task<ProductsResult> GetProducts()
        {
            try
            {
                _logger.LogInformation("Attempting to get products from API");
                var productResponse = await _httpClient.GetAsync("/api/products");
                
                _logger.LogInformation($"API Response Status: {productResponse.StatusCode}");
                
                var result = new ProductsResult()
                {
                    Success = productResponse.IsSuccessStatusCode,
                    ErrorMessage = productResponse.ReasonPhrase,
                };

                if (productResponse.IsSuccessStatusCode)
                {
                    var responseContent = await productResponse.Content.ReadAsStringAsync();
                    _logger.LogInformation($"API Response Content: {responseContent}");
                    
                    var products = JsonConvert.DeserializeObject<List<Product>>(responseContent);
                    result.Products = products;
                    _logger.LogInformation($"Successfully deserialized {products?.Count ?? 0} products");
                }
                else
                {
                    var errorContent = await productResponse.Content.ReadAsStringAsync();
                    _logger.LogError($"API call failed with status {productResponse.StatusCode}: {errorContent}");
                    result.ErrorMessage = $"{productResponse.ReasonPhrase}: {errorContent}";
                }

                return result;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Exception occurred while calling API");
                return new ProductsResult
                {
                    Success = false,
                    ErrorMessage = $"Exception: {ex.Message}",
                    Products = new List<Product>()
                };
            }
        }

        public async Task<ProductResult> GetProduct(int id)
        {
            var productResponse = await _httpClient.GetAsync($"/api/products/{id}");

            var result = new ProductResult()
            {
                Success = productResponse.IsSuccessStatusCode,
                ErrorMessage = productResponse.ReasonPhrase,
            };

            if (productResponse.IsSuccessStatusCode)
            {
                var product = JsonConvert.DeserializeObject<Product>(await productResponse.Content.ReadAsStringAsync());
                result.Product = product;
            }

            return result;
        }

        public async Task<ProductResult> UpdateProduct(Product product)
        {

            var productResponse = await _httpClient.PutAsJsonAsync($"/api/products/{product.Id}", product);

            var result = new ProductResult()
            {
                Success = productResponse.IsSuccessStatusCode,
                ErrorMessage = productResponse.ReasonPhrase,
            };

            if (productResponse.IsSuccessStatusCode)
            {
                result.Product = product;
            }

            return result;
        }

        public async Task<ProductResult> CreateProduct(Product product)
        {
            var productResponse = await _httpClient.PostAsJsonAsync($"/api/products", product);

            var result = new ProductResult()
            {
                Success = productResponse.IsSuccessStatusCode,
                ErrorMessage = productResponse.ReasonPhrase,
            };

            if (productResponse.IsSuccessStatusCode)
            {
                var newProduct = JsonConvert.DeserializeObject<Product>(await productResponse.Content.ReadAsStringAsync());
                result.Product = newProduct;
            }

            return result;
        }
    }
}
