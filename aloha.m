clc;clear all; %close all;

%PARAMETROS DE SIMULA��O
%simula��o do protocolo Aloha puro
%tempo total da simula��o em segundos
tempo = 1;
%n�mero total de esta��es
n_est = 10;
%taxa de transmiss�o do meio em bits por segundo
taxa_bits = 1e4; % 10 kbps
%tamanho do quadro em bits
tam_quadro = 100; % portanto, haver�, no m�ximo, 1*1e4/100 = 100 quadros no tempo da simula��o

%janela de tempo de espera aleat�rio em n�mero de instantes de simula��o
espera_max =10*tam_quadro;

%tempo de transmiss�o do quadro em segundos
t_quadro = tam_quadro/taxa_bits;
%intervalo de tempo da simula��o
%dt_sim = t_quadro/tam_quadro;
dt_sim = 1/taxa_bits;
%tempo total da simula��o em instantes
t_sim = ceil(tempo/dt_sim); % = tempo*taxa_bits;

% n�mero de simula��es
nsim = 10;

%n�mero de repeti��es da simula��o - para tirar a m�dia
rodadas = 4;

%taxa m�dia m�xima de chegada de quadros por esta��o
taxa_max_quadro=ceil(taxa_bits*tempo/tam_quadro/n_est);

% aumento da taxa de quadros

taxas_quadro = taxa_max_quadro*(1/nsim:1/nsim:1);

%tamanho do quadro (ajustado por passos de simula��o)
tam_q = ceil(tam_quadro/taxa_bits/dt_sim);

% resultados da simula��o
quadros_transmitidos = zeros(1,nsim);
quadros_entregues = zeros(1,nsim);
quadros_gerados = zeros(1,nsim);
quadros_colididos = zeros(1,nsim);
quadros_fila = zeros(1,nsim);

tic;

%armazenador das transmiss�es
transmis=zeros(nsim, n_est,t_sim);

for s=1:nsim
  taxa_quadro = taxas_quadro(s);
  %Progresso da simula��o
  clc;disp(['Progresso: ' num2str(100*taxa_quadro/taxa_max_quadro) '%']);
	%taxa m�dia de chegada de quadros por instante de simula��o
	tm_q=taxa_quadro*dt_sim;

	for r=1:rodadas
		%VARIAVEIS DOS EVENTOS
		%transmissores ativos
		tx_ativo = zeros(1,n_est);
		%fila de quadros do transmissor
		tx_fila = zeros(1,n_est);
		%contador de progresso do transmissor
		tx_cnt=zeros(1,n_est);
		%armazenador de colis�es
		colis=zeros(1,t_sim);
		%indices das esta��es com colis�o
		colin=zeros(1,n_est);
		%espera aleat�ria em caso de colis�o
		tx_espera=zeros(1,n_est);

		%armazenador da chegada dos quadros
		chegada_quadros=0;
        % armazenador de quadros colididos
        colisoes = 0;
        % armazenador de quadros entregues
        entregues = 0;
        % armazenador de quadros transmitidos
        transmitidos = 0;

		for t=1:t_sim
			for n=1:n_est
			    %verificar se o transmissor est� ativo
			    if tx_ativo(n)==1
			        transmis(s,n,t)=1;
			    end
			    %verificar se o quadro foi enviado
			    if tx_cnt(n)>0
			        tx_cnt(n)=tx_cnt(n)-1;
			        if tx_cnt(n)==0
			            tx_ativo(n)=0;
			            %verificar se a transmiss�o sofreu colis�o
			            if colin(n)==1
			                tx_espera(n)=ceil(espera_max*rand(1));
			                tx_fila(n)=tx_fila(n)+1;
			                colin(n)=0;
                            colisoes = colisoes + 1;
                        else
                            entregues = entregues + 1;
                        end
			        end
			    else
			    	% verificar se tem quadros em espera
			        if (tx_fila(n)>0) && (tx_espera(n)==0)
                        transmitidos = transmitidos+1;
			            tx_ativo(n)=1;
			            tx_cnt(n)=tam_q;
			            tx_fila(n)=tx_fila(n)-1;
              else
                  if tx_espera(n)>0
                     %decrementar o contador do tempo de espera
                     tx_espera(n)=tx_espera(n)-1;
                  end
          end
        end

        % verificar se chegou um novo quadro
        p_novo=rand(1);
        if p_novo < tm_q
           chegada_quadros=chegada_quadros+1;
           %verificar se o transmissor est� pronto
           if (tx_ativo(n)==0) && (tx_espera(n)==0)
               transmitidos = transmitidos +1;
               tx_ativo(n)=1;
               tx_cnt(n)=tam_q;
           else
               tx_fila(n)=tx_fila(n)+1;
           end
        end
       end
        %verifica se houve colis�o
        if sum(tx_ativo)>1
            colis(t)=1;
            colin = tx_ativo;
        end
    end

      % armazena resultados
      quadros_transmitidos(s)=quadros_transmitidos(s) + transmitidos/rodadas;
      quadros_entregues(s)=quadros_entregues(s) + entregues/rodadas;
      quadros_gerados(s)=quadros_gerados(s) + chegada_quadros/rodadas;
      quadros_colididos(s) = quadros_colididos(s) + colisoes/rodadas;
      quadros_fila(s) = quadros_fila(s) + sum(tx_fila)/rodadas;
    end
end
toc;

% resultados
if 1 % significado
    disp('s => ID da simula��o, G => gerados, T => transmitidos, E => entregues, C => colididos, F => na fila');
end

for s=1:nsim
  disp(['s:' num2str(s) ' G:' num2str(quadros_gerados(s)) ' T:' num2str(quadros_transmitidos(s)) ' E:' num2str(quadros_entregues(s)) ' C:' num2str(quadros_colididos(s)) ' F:' num2str(quadros_fila(s)) ' S:' num2str(quadros_entregues(s)/(quadros_entregues(s)+quadros_colididos(s)))]);
end

% quadros_entregues
% quadros_colididos
% quadros_transmitidos
% quadros_gerados
% quadros_fila

% gr�fico de barras
figure;
bar([quadros_gerados', quadros_entregues', quadros_colididos', quadros_fila']);

G = 0:0.01:2;
S = G.*exp(-2*G);
hold on;
figure;
plot((quadros_entregues+quadros_colididos)*tam_quadro/tempo,quadros_entregues*tam_quadro/tempo,'ro',G*taxa_bits,S*taxa_bits,'-')
grid
xlabel('Taxa de chegada de quadros (bps)');
ylabel('Taxa de entrega de quadros - capacidade (bps)');

% diagrama temporal
s=3; % ID da simula��o para gerar o diagrama
transmis_s = squeeze(transmis(s,:,:));
figure; hold on;
for m=1:n_est
  plot(transmis_s(m,:)'*m,'o');
end

