using SmartAgri.Api.Interfaces;

namespace SmartAgri.Api.Services;

public class AIService : IAIService
{
    public Task<string> AnalyzeFarmAsync(string farmData)
    {
        return Task.FromResult($"AI analysis for farm data: {farmData}");
    }

    public Task<IEnumerable<string>> GetRecommendationsAsync(string request)
    {
        return Task.FromResult<IEnumerable<string>>(new[] { "Recommendation 1", "Recommendation 2" });
    }
}
