# CosmicTile — escopo aprovado
App Swift/AppKit inspirado no tiling do COSMIC, sem reutilizar código ou identidade visual. Um layout independente por monitor; divisões horizontais/verticais; atalhos de foco, troca, redimensionamento, flutuação e transferência de monitor. Acessibilidade controla janelas. Posições originais são restauradas ao desligar. Conexão e desconexão de monitores dispara reconciliação. Pilhas com abas ficam para outra versão.

Limites: gerencia janelas acessíveis no Space atual; não substitui o compositor nem controla Spaces com APIs privadas. Apps podem impor tamanho mínimo. Não altera janelas até ativação explícita.

# Plano de implementação
1. TileCore: árvore binária, inserção, remoção, geometria e redimensionamento. Testar conservação da área, gaps e remoção.
2. Adaptador AX: enumerar janelas padrão, ler/escrever frames e focar. Ignorar minimizadas/fullscreen e erros por janela.
3. Controlador: reconciliar por monitor, reter frames originais, flutuação e movimentação entre monitores; pausa em mudanças de Space.
4. AppKit: menu, permissão, atalhos globais Carbon, preferências de gaps e build de app bundle.
5. Verificar swift test, build release e integridade do bundle. Validação de janelas reais depende da permissão de Acessibilidade.
