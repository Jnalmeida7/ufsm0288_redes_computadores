clc; clear all; close all;

% Inicia o gerador de numeros aleatorios
rand("state", 0);

% Parametros principais
tempo_simulacao = 100; % tempo de simulacao
n=3; % numero de nos da rede

% Lista de eventos executados
global Log_eventos = [];
global eventos_executados = 0;

global msg = {"hello"};
global rede = ~eye(n); % matriz de conectividade da rede
global nos = []; % para guardar informações dos nós da rede

function Log_eventos = exec_simulador(Lista_eventos, Log_eventos, tempo_final)

  global eventos_executados;

% Simulacao discreta por eventos
  while 1
    [min_instante, min_indice] = min([Lista_eventos(:).instante]);
    if isempty(min_instante)
        break;
    end
    if min_instante > tempo_final
        break;
    end

    ev = Lista_eventos(min_indice);
    Lista_eventos(min_indice) = []; % Remove o evento da lista, pois sera executado.
    tempo_atual = min_instante;
    Log_eventos = [Log_eventos;ev];

    Novos_eventos = executa_evento(ev, tempo_atual);    % Retorna os novos eventos apos executar o ultimo evento
    eventos_executados += 1;


    if ~isempty(Novos_eventos) % adiciona novos eventos na lista
      Lista_eventos = [Lista_eventos;Novos_eventos];
    end
  end
endfunction;

function [NovosEventos] = executa_evento(evento, tempo_atual)
    global msg, global rede, global nos;

    NovosEventos = [];

    ### configuração do sistema de comunicação
    distancia = 100; % 100m
    velocidade_sinal = 3e8;
    tempo_prop = distancia/velocidade_sinal; %tempo de propagacao = distancia/velocidade do sinal
    taxa_dados = 1e5; % 100kbps
    tempo_espera_max = 20*8/taxa_dados; % tempo máximo de espera
    csma = 0; % 1 para CSMA, 0 para Aloha

    [t,tipo_evento, id, pct]= evento_desmonta(evento); % retorna os campos do 'evento'
    disp(['EV: ' tipo_evento ' @t=' num2str(t) ' id=' num2str(id)]);

    switch tipo_evento
        case 'N_cfg' % configura nos, inicia variaveis de estado, etc.
            % inicia estrutura de dados de cada nó
            % Tx e Rx independentes, permitindo comunicação full-duplex
            nos(id).Tx = 'desocupado';
            nos(id).Rx = 'desocupado';
            nos(id).ocupado_ate = 0;
            nos(id).rx_ocupado = 0
            nos(id).stat = struct("tx", 0, "rx", 0, "rxok", 0, "col", 0, "txok", 0, "col_ack", 0);

            # adiciona uma trasmissao na fila
            % pacote contem origem (src), destino (dst), tamanho (tam) e os dados
            % dst = 2
            if (id == 1)
              dst = 2;
              pct =  struct('src', id, 'dst', dst, 'tam', 20, 'dados', msg);
              e = evento_monta(tempo_atual+rand(1), 'T_ini', id, pct);
              NovosEventos =[NovosEventos;e];
            endif

      case 'T_ini' %inicio de transmissao
           if strcmp(nos(id).Tx, 'ocupado') % transmissor ocupado?
             disp(['Tx ocupado']);
             tempo_entre_quadros = 0.2*8*pct.tam/taxa_dados; %20\% do tempo de transmissao
             e = evento_monta(nos(id).ocupado_ate+tempo_entre_quadros, 'T_ini', id, pct);
             NovosEventos =[NovosEventos;e];
           elseif strcmp(nos(id).Rx, 'ocupado') && csma == 1 % receptor ocupado?
             tempo_espera = rand(1)*tempo_espera_max;
             e = evento_monta(tempo_atual + tempo_espera, 'T_ini', id, pct);
             NovosEventos =[NovosEventos;e];
           else
             % sempre broadcast (difusao)
              for nid = find(rede(id,:)>0) % envia uma copia do pacote para cada vizinho
                disp(['INI T (de ' num2str(id) ' para ' num2str(nid) ')' ]);
                %pct.dst = nid;
                e = evento_monta((tempo_atual+tempo_prop), 'R_ini', nid, pct);
                NovosEventos =[NovosEventos;e];
              end
             tempo_transmissao = 8*pct.tam/taxa_dados;
             e = evento_monta((tempo_atual+tempo_transmissao), 'T_fim', id, pct);
             NovosEventos =[NovosEventos;e];
             nos(id).Tx = 'ocupado';
             nos(id).ocupado_ate = tempo_atual+tempo_transmissao;
          end
      case 'T_fim' %fim de transmissao
             nos(id).stat.tx +=1;
             nos(id).Tx = 'desocupado';
             nos(id).ocupado_ate = 0;
      case 'R_ini' %inicio de recepcao
             %if ~isempty(pct); disp(pct); end;
             if strcmp(nos(id).Rx, 'ocupado') ||  strcmp(nos(id).Rx, 'colisao')
               nos(id).Rx  = 'colisao';
               nos(id).rx_ocupado +=1;
             else % desocupado
               nos(id).Rx  = 'ocupado';
               nos(id).rx_ocupado = 1;
             end;
             e = evento_monta((tempo_atual+8*pct.tam/taxa_dados), 'R_fim', id, pct);
             NovosEventos =[NovosEventos;e];
    case 'R_fim' %fim de recepcao
            nos(id).rx_ocupado -=1;
            if strcmp(nos(id).Rx, 'ocupado')
                disp(['FIM R (de ' num2str(pct.src) ' para ' num2str(pct.dst) ')']);
                %if ~isempty(pct); disp(pct); end;
                nos(id).Rx  = 'desocupado';
                nos(id).rx_ocupado = 0;
                nos(id).stat.rx +=1; % contador de recepções

                % inicia T ACK
                if (id == pct.dst)
                  nos(id).stat.rxok +=1; % contador de recepções com sucesso
                  dst = pct.src;
                  pct.src = id;
                  pct.dst = dst;
                  pct.tam = 2;
                  pct.msg = 'ACK';
                  e = evento_monta((tempo_atual), 'T_ini_ack', id, pct);
                  NovosEventos =[NovosEventos;e];
                end

            elseif  strcmp(nos(id).Rx, 'colisao')
                disp(['COLISAO (de ' num2str(pct.src) ' para ' num2str(pct.dst) ')']);
                if(nos(id).rx_ocupado == 0)
                  nos(id).Rx  = 'desocupado';
                end
                nos(id).stat.col +=1;
            else
              disp("ERRO: Estado Rx errado.");
            end

       case 'T_ini_ack'
            if strcmp(nos(id).Tx, 'desocupado') % transmissor desocupado?
                disp(['INI T ACK (de ' num2str(pct.src) ' para ' num2str(pct.dst) ')' ]);
                tempo_transmissao = 8*pct.tam/taxa_dados;
                e = evento_monta((tempo_atual+tempo_transmissao), 'T_fim_ack', id, pct);
                NovosEventos =[NovosEventos;e];
                nos(id).Tx = 'ocupado';

                e = evento_monta((tempo_atual+tempo_prop), 'R_ini_ack', pct.dst, pct);
                NovosEventos =[NovosEventos;e];
            endif
       case 'T_fim_ack'
            nos(id).Tx = 'desocupado';
       case 'R_ini_ack'
              if strcmp(nos(id).Rx, 'ocupado') ||  strcmp(nos(id).Rx, 'colisao')
               nos(id).Rx  = 'colisao';
               nos(id).rx_ocupado +=1;
              else % desocupado
               nos(id).Rx  = 'ocupado';
               nos(id).rx_ocupado = 1;
              end;
              tempo_transmissao = 8*pct.tam/taxa_dados;
              e = evento_monta((tempo_atual+tempo_transmissao), 'R_fim_ack', id, pct);
              NovosEventos =[NovosEventos;e];
       case 'R_fim_ack'
            nos(id).rx_ocupado -=1;
            if strcmp(nos(id).Rx, 'ocupado')
                % recebeu o ACK
                disp(['FIM R ACK (de ' num2str(pct.src) ' para ' num2str(pct.dst) ')']);
                nos(id).stat.txok +=1; % contador de transmissões com sucesso
                nos(id).Rx  = 'desocupado';
                nos(id).rx_ocupado = 0;
            elseif  strcmp(nos(id).Rx, 'colisao')
                disp(['COLISAO ACK (de ' num2str(pct.src) ' para ' num2str(pct.dst) ')']);
                if(nos(id).rx_ocupado == 0)
                  nos(id).Rx  = 'desocupado';
                end
                nos(id).stat.col_ack +=1;
            else
              disp("ERRO: Estado Rx errado.");
            end

       case 'S_fim' %fim de simulacao
             disp('Simulacao encerrada!');
       otherwise
             disp(['exec_evento: Evento desconhecido: ' tipo_evento]);
    end;

endfunction;

function [t, tipo, id, pct]= evento_desmonta(e)
  t=e.instante;
  tipo=e.tipo;
  id = e.id;
  pct=e.pct;
endfunction;

function e=evento_monta(t, tipo, id, pct)
  if nargin<4, pct=[]; end
  e=struct('instante', t, 'tipo', tipo, 'id', id);
  e.pct=pct;
endfunction;


function Lista_eventos = config_sim(n, tempo_simulacao)
  Lista_eventos = [];
  for k=1:n
    e = evento_monta(0, 'N_cfg', k);
    Lista_eventos = [Lista_eventos;e];
  end

  ev_fim = evento_monta(tempo_simulacao, 'S_fim', 0);
  Lista_eventos = [Lista_eventos; ev_fim];
endfunction;

% Configura a simulacao
tempo_inicial = clock();
Lista_eventos = config_sim(n, tempo_simulacao);

% Executa a simulacao
Log_eventos = exec_simulador(Lista_eventos, Log_eventos, tempo_simulacao);
##print_struct_array_contents(1);
##Log_eventos(:).instante
##Log_eventos(:).tipo
disp(['---Total de eventos=' num2str(eventos_executados)]);
disp(sprintf('---Tempo da simulacao=%g segundos', etime(clock, tempo_inicial)));




