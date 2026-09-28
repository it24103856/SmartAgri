SELECT "Id", "Status", "UpdatedAt" 
FROM "SmartBasketWorkflows" 
ORDER BY "CreatedAt" DESC 
LIMIT 3;

SELECT "AgentName", "Status", "ErrorMessage", CAST("OutputJson" AS VARCHAR)
FROM "SmartBasketSteps"
ORDER BY "FinishedAt" DESC NULLS LAST
LIMIT 3;
