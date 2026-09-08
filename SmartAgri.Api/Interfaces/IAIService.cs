namespace SmartAgri.Api.Interfaces;

public interface IAIService
{
    Task<string> AnalyzeFarmAsync(string farmData);
    Task<IEnumerable<string>> GetRecommendationsAsync(string request);
}
