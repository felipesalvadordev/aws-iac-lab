const mysql = require('mysql2/promise');

// Database configuration moved outside the handler for reuse across warm starts
const dbConfig = {
    host: process.env.DB_HOST,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
    port: process.env.DB_PORT || 3306,
    connectTimeout: 5000
};

// Global variable to persist the connection pool
let pool;

exports.handler = async (event) => {
    // Initialize the pool only once during the container's lifecycle
    if (!pool) {
        pool = mysql.createPool(dbConfig);
    }

    try {
        // 1. ADMINISTRATIVE MODE: Execute SQL queries (e.g., from PowerShell scripts)
        if (event.is_query === true) {
            const [rows] = await pool.execute(event.sql);
            return {
                statusCode: 200,
                body: JSON.stringify(rows)
            };
        }

        // 2. DEFAULT MODE: API Logging (Triggered via Web/API Gateway)
        const { requestContext, path, httpMethod, headers } = event;
        const requestId = requestContext?.requestId || 'N/A';
        const logPath = path || '/';
        const method = httpMethod || 'GET';
        const ip = requestContext?.identity?.sourceIp || '0.0.0.0';
        const agent = headers?.['User-Agent'] || 'Unknown';

        const insertQuery = `INSERT INTO api_logs (request_id, path, method, ip_address, user_agent) VALUES (?, ?, ?, ?, ?)`;
        
        // Use pool.execute for prepared statements and automatic connection management
        await pool.execute(insertQuery, [requestId, logPath, method, ip, agent]);

        return {
            statusCode: 200,
            headers: {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "https://felipesalvador.com.br"
            },
            body: JSON.stringify({ message: "Log recorded successfully!", requestId }),
        };

    } catch (error) {
        console.error("Lambda Error:", error);
        return {
            statusCode: 500,
            body: JSON.stringify({ error: "Database operation failed", details: error.message }),
        };
    }
    // Optimization: We do not call pool.end() to keep connections alive for the next invocation
};