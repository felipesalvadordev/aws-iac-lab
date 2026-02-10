const mysql = require('mysql2/promise');

exports.handler = async (event) => {
    const dbConfig = {
        host: process.env.DB_HOST,
        user: process.env.DB_USER,
        password: process.env.DB_PASSWORD,
        database: process.env.DB_NAME,
        port: process.env.DB_PORT || 3306,
        connectTimeout: 5000
    };

    let connection;

    try {
        connection = await mysql.createConnection(dbConfig);

        // 1. Garante que a tabela existe
        await connection.execute(`
            CREATE TABLE IF NOT EXISTS api_logs (
                id INT AUTO_INCREMENT PRIMARY KEY,
                request_id VARCHAR(100),
                path VARCHAR(255),
                method VARCHAR(10),
                ip_address VARCHAR(45),
                user_agent TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        `);

        // 2. VERIFICAÇÃO: É uma consulta do script PowerShell?
        if (event.is_query === true) {
            const [rows] = await connection.execute(event.sql);
            return {
                statusCode: 200,
                body: JSON.stringify(rows) // Retorna os dados para o PowerShell
            };
        }

        // 3. MODO PADRÃO: Registro de logs (Executado via Navegador/API)
        const requestId = event.requestContext?.requestId || 'N/A';
        const path = event.path || '/';
        const method = event.httpMethod || 'GET';
        const ip = event.requestContext?.identity?.sourceIp || '0.0.0.0';
        const agent = event.headers?.['User-Agent'] || 'Unknown';

        const insertQuery = `INSERT INTO api_logs (request_id, path, method, ip_address, user_agent) VALUES (?, ?, ?, ?, ?)`;
        await connection.execute(insertQuery, [requestId, path, method, ip, agent]);

        return {
            statusCode: 200,
            headers: {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "https://felipesalvador.com.br"
            },
            body: JSON.stringify({ message: "Sucesso!", requestId }),
        };

    } catch (error) {
        console.error("Erro na Lambda:", error);
        return {
            statusCode: 500,
            body: JSON.stringify({ error: "Falha no banco", details: error.message }),
        };
    } finally {
        if (connection) await connection.end();
    }
};