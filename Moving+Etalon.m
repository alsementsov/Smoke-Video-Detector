%% Переменные и Константы

Frame_first=2;

Cell_size=16; % Размер ячейки
LH_frames=80; %Кол-во кадров состояния LH до апдейта 80
Repeat_frames=200; %10/20 Кол-во кадров повторения фона после изменения.
ThRepeat = 7;

BG_H = uint32(8*Cell_size*Cell_size);% 10-Уровень  изменения фона  (Сильное изменение)
BG_L = uint32(4*Cell_size*Cell_size);% 4Уровень фона (Слабое изменение) - Сигнал на обновление
BG_old_l = uint32(5*Cell_size*Cell_size); %4Уровень изменения фона для old (для апдейта не должен быть большим)
BG_old_h = uint32(7*Cell_size*Cell_size);
BG_Move = uint32(Movthres*Cell_size*Cell_size); % Порог для маски движения 16
%Prev_Move = uint32(Prthres*Cell_size*Cell_size); %Порог для маски движения (n-1) 8

E_High = uint8(100);
E_Low = uint8(60);

CoefMult2=10000;%100

[V,H] = size(I);
Vsize = uint16(fix(V/Cell_size)+1);
Hsize = uint16(fix(H/Cell_size)+1);
%2wavelet
segn = fix(V/Cell_size);
segm = fix(H/Cell_size);
%маска сброса зон по отсутсвию движения
reset_wlow_mask=false(Vsize,Hsize);

persistent time
if isempty(time)
    time = uint32(1);
else
    time = time+1;
end
Frame=time;
persistent Fcounter
if isempty(Fcounter)
    Fcounter = uint8(0);
end
persistent KeyFrame
if isempty(KeyFrame)
    KeyFrame = struct('I',uint8(zeros(V,H)),'R',uint8(zeros(V,H)),'G',uint8(zeros(V,H)),'B',uint8(zeros(V,H)));
end;
persistent Frame_old
if isempty(Frame_old)
    Frame_old = struct('I',uint8(zeros(V,H)),'R',uint8(zeros(V,H)),'G',uint8(zeros(V,H)),'B',uint8(zeros(V,H)));
end;
persistent Mask_Color
if isempty(Mask_Color)
    Mask_Color = false(V,H);
end
persistent Imean
if isempty(Imean)
    Imean = uint8(0);
end
persistent Imean_Prev
if isempty(Imean_Prev)
    Imean_Prev= uint8(0);
end
persistent W_flag_low
if isempty(W_flag_low)
    W_flag_low=false(Vsize,Hsize);
end;
persistent delta
if isempty(delta)
    delta=zeros(Vsize,Hsize);
end;
persistent Etable
if isempty (Etable)
    Etable=int32(zeros(Vsize,Hsize));
end
persistent EtableEt
if isempty (EtableEt)
    EtableEt=int32(zeros(Vsize,Hsize));
end
persistent Emean
if isempty(Emean)
    Emean=int32(0);
end
persistent EmeanEt
if isempty(EmeanEt)
    EmeanEt=int32(0);
end
persistent txins
if isempty(txins)
    txins = vision.TextInserter('Text', '%4d', 'Location',  [0 4], ...
        'Color', [0 0 0], 'FontSize', 7);
end
persistent Imtab
if isempty(Imtab)
    Imtab=uint8(zeros(V,H,1));
end
Imseg1 =uint8(zeros(Cell_size,Cell_size));

BKG_out=false(Vsize,Hsize);
ws=Cell_size/2;
LL1=zeros(ws,ws);
LH1=zeros(ws,ws);
HL1=zeros(ws,ws);
HH1=zeros(ws,ws);
LL2=zeros(ws,ws);
LH2=zeros(ws,ws);
HL2=zeros(ws,ws);
HH2=zeros(ws,ws);
Id=zeros(V,H);
Ikfd=zeros(V,H);
%
TCell=struct('Sub_EtalonR',uint32(0),'Sub_EtalonG',uint32(0),'Sub_EtalonB',uint32(0),...
    'Sub_EtalonI',uint32(0),'Sub_PrevR',uint32(0),'Sub_PrevG',uint32(0),'Sub_PrevB',uint32(0),...
    'Sub_PrevI',uint32(0),'Rewrite',false,'LH_Counter',uint8(0), 'Repeat_Counter',uint8(0),'MoveMask',false,'Imean_Rewrite',uint8(0));%
persistent Cells
if isempty(Cells)
    Cells = repmat(TCell,Vsize,Hsize);
end
%Etalon_out =uint8(zeros(V,H));
coder.extrinsic('dwt2','im2double');
%% MAIN
% Запись первого кадра
if time == Frame_first
    KeyFrame.R=R;
    KeyFrame.G=G;
    KeyFrame.B=B;
    KeyFrame.I=I;
    Frame_old.R=uint8(R);
    Frame_old.G=uint8(G);
    Frame_old.B=uint8(B);
    Frame_old.I=uint8(I);
    Isum=uint32(sum(I(:)));
    Imean=uint8(Isum/(V*H));
end
%Счетчик N-го кадра
if (Fcounter<fix(Fdelta/2))&&(time > Frame_first)%849
    Fcounter=Fcounter+1;
else
    Fcounter=uint8(1);
end;

go_out=0;
% Если кадр кратен N
if (Fcounter==1) && (time > Frame_first)
    Isum=uint32(0);
    Isum_KF=uint32(0);
    go_out=1;
    for i=1:V
        for j=1:H
            Isum= Isum+uint32(I(i,j));
            Isum_KF=Isum_KF+uint32(KeyFrame.I(i,j));
            %% Маска по цвету
            Mask_Color(i,j)=false;
            % Sum_delta= abs(int16(R(i,j))-int16(G(i,j))) + abs(int16(R(i,j))-int16(B(i,j))) + abs(int16(B(i,j))-int16(G(i,j)));
            % Поиск максимума и минимума
            if (R(i,j)>=G(i,j)) && (R(i,j)>=B(i,j))
                maxi=R(i,j);
                if G(i,j)>B(i,j)
                    mini=B(i,j);
                    mean=G(i,j);
                else
                    mini=G(i,j);
                    mean=B(i,j);
                end;
            else
                if G(i,j)>B(i,j)
                    maxi=G(i,j);
                    if R(i,j)>B(i,j)
                        mini=B(i,j);
                        mean=R(i,j);
                    else
                        mini=R(i,j);
                        mean=B(i,j);
                    end;
                else
                    maxi=B(i,j);
                    if R(i,j)>G(i,j)
                        mini=G(i,j);
                        mean=R(i,j);
                    else
                        mini=R(i,j);
                        mean=G(i,j);
                    end;
                end;
            end;
            %Вычисление дельт
            delta_max=maxi-mini;
            delta_left=mean-mini;
            delta_right=maxi-mean;
            if delta_left>delta_right
                delta_min=delta_right;
            else
                delta_min=delta_left;
            end;
            % Условие Цветности
            if delta_max>86
                Mask_Color(i,j)=true;
            else
                if delta_max>50
                    if (delta_max/maxi)>0.5
                        Mask_Color(i,j)=true;
                    end
                    if (delta_max/delta_min) >7
                        Mask_Color(i,j)=true;
                    end
                end
            end
            
            %% Рачет фона для Cells
            n=uint16(fix((i-1)/Cell_size)+1);
            m=uint16(fix((j-1)/Cell_size)+1);
            if n > Vsize
                n=uint16(Vsize);
            end
            if m > Hsize
                m=uint16(Hsize);
            end
            if  ~(Mask_Color(i,j))
                % Сравнение с эталоном
                Cells(n,m).Sub_EtalonR=Cells(n,m).Sub_EtalonR+uint32(abs(int16(KeyFrame.R(i,j))-int16(R(i,j))));
                Cells(n,m).Sub_EtalonG=Cells(n,m).Sub_EtalonG+uint32(abs(int16(KeyFrame.G(i,j))-int16(G(i,j))));
                Cells(n,m).Sub_EtalonB=Cells(n,m).Sub_EtalonB+uint32(abs(int16(KeyFrame.B(i,j))-int16(B(i,j))));
                Cells(n,m).Sub_EtalonI=Cells(n,m).Sub_EtalonI+uint32(abs( int16(KeyFrame.I(i,j))-int16(I(i,j))));
                % Сравнение с N-1 кадром
                Cells(n,m).Sub_PrevR=Cells(n,m).Sub_PrevR+uint32(abs(int16(Frame_old.R(i,j))-int16(R(i,j))));
                Cells(n,m).Sub_PrevG=Cells(n,m).Sub_PrevG+uint32(abs(int16(Frame_old.G(i,j))-int16(G(i,j))));
                Cells(n,m).Sub_PrevB=Cells(n,m).Sub_PrevB+uint32(abs(int16(Frame_old.B(i,j))-int16(B(i,j))));
                Cells(n,m).Sub_PrevI=Cells(n,m).Sub_PrevI+uint32(abs( int16(Frame_old.I(i,j))-int16(I(i,j))));
            end
            Frame_old.R(i,j)=R(i,j);
            Frame_old.G(i,j)=G(i,j);
            Frame_old.B(i,j)=B(i,j);
            Frame_old.I(i,j)=I(i,j);
        end
    end
    % Средняя яркость текущего кадра и эталонного
    Imean=uint8(Isum/(V*H));
    %% Анализ фона в ячейках
    for n=1:Vsize
        for m=1:Hsize
            if (abs(int16(Imean_Prev)-int16(Imean))>30)
                Cells(n,m).Rewrite=true;
            else
                %% Маска движения
                if  (Cells(n,m).Sub_EtalonR>=BG_Move) ||  (Cells(n,m).Sub_EtalonG>=BG_Move) ...
                        ||(Cells(n,m).Sub_EtalonB>=BG_Move) || (Cells(n,m).Sub_EtalonI>=BG_Move)
                    %Маска Движения
                    Cells(n,m).MoveMask=true;
                else
                    Cells(n,m).MoveMask=false;
                end;
                %% Проверка межкадровой повторяемости в зонах (корректор выходных масок)
                if (Cells(n,m).Repeat_Counter > ThRepeat)
                    Cells(n,m).MoveMask=false;
                    % МАТРИЦА ФЛАГОВ СБРОСА ЗОН в ВЕВЛЕТ-маске
                    reset_wlow_mask(n,m)=true;
                else
                    reset_wlow_mask(n,m)=false;
                end;
                % Адаптация порога для роста счетчика Repeat
                if (Etable(n,m)>=E_High)
                    BG_old=BG_old_h;
                else
                    BG_old=BG_old_l;
                end
                %% Для Обновления
                % Условие 1 - Если зона на текущем кадра сильно отличается от эталона
                if  ((Cells(n,m).Sub_EtalonR>=BG_H) ||  (Cells(n,m).Sub_EtalonG>=BG_H) ...
                        ||(Cells(n,m).Sub_EtalonB>=BG_H) || (Cells(n,m).Sub_EtalonI>=BG_H))%&&Cells(n,m).MoveMask==false);%815  
                    Cells(n,m).LH_Counter=uint8(0);
                    % 1.1 Нет изменений между соседними кадрами + счетчик таких событий
                    if (((Cells(n,m).Sub_PrevB<BG_old) && (Cells(n,m).Sub_PrevI<BG_old)) ...
                            || ((Cells(n,m).Sub_PrevG<BG_old) && (Cells(n,m).Sub_PrevI<BG_old))...
                            ||((Cells(n,m).Sub_PrevR<BG_old) && (Cells(n,m).Sub_PrevI<BG_old)))
                        % Счетчик повторяемости соседних кадров
                        Cells(n,m).Repeat_Counter=Cells(n,m).Repeat_Counter+1;
                        %Условия для обновления (Rewrite) 
                        if (Etable(n,m) < E_Low)
                            if(Cells(n,m).Repeat_Counter >= (Repeat_frames*3))
                                Cells(n,m).Rewrite=true;
                            end
                        elseif (Etable(n,m) < E_High)
                            if(Cells(n,m).Repeat_Counter >= (Repeat_frames*2))
                                Cells(n,m).Rewrite=true;
                            end
                        else
                            if (Cells(n,m).Repeat_Counter >= Repeat_frames)
                                Cells(n,m).Rewrite=true;
                            end
                        end
                    else
                        Cells(n,m).Repeat_Counter=uint8(0);
                    end
                % Условие 2 - Если зона на текущем кадре совсем слабо отличается от эталона (для наступления сумерек или  рассвета - плавного)
                elseif (Cells(n,m).Sub_EtalonR<BG_L) && (Cells(n,m).Sub_EtalonG<BG_L) &&  (Cells(n,m).Sub_EtalonB<BG_L) && (Cells(n,m).Sub_EtalonI<BG_L) %Нет изменений ни в одном канале
                    Cells(n,m).Rewrite=true;% ОБНОВЛЕНИЕ
                % Условие 3 - Если не У1 и не У2, те когда среднее изменение от эталона = от BG_L до BG_H (используется счетчик LH_COUNTER)
                else
                    Cells(n,m).LH_Counter = Cells(n,m).LH_Counter+1;
                    if Cells(n,m).LH_Counter >=LH_frames
                        Cells(n,m).Rewrite=true; % ОБНОВЛЕНИЕ
                    end
                end;
            end;
            %% Перезапись эталона по Rewrite или резкому изменению яркости кадра
            Cells(n,m).Sub_EtalonR = uint32(0);
            Cells(n,m).Sub_EtalonG = uint32(0);
            Cells(n,m).Sub_EtalonB = uint32(0);
            Cells(n,m).Sub_EtalonI = uint32(0);
            Cells(n,m).Sub_PrevR = uint32(0);
            Cells(n,m).Sub_PrevG = uint32(0);
            Cells(n,m).Sub_PrevB = uint32(0);
            Cells(n,m).Sub_PrevI = uint32(0);
            
            if Cells(n,m).Rewrite
                Cells(n,m).Rewrite=false;
                Cells(n,m).LH_Counter=uint8(0);
                Cells(n,m).Repeat_Counter=uint8(0);
                Cells(n,m).Imean_Rewrite=Imean;%
                
                xo=(m-1)*Cell_size+1;
                xn=m*Cell_size;
                yo=(n-1)*Cell_size+1;
                yn=n*Cell_size;
                if yn>V
                    yn=uint16(V);
                end;
                if xn>H
                    xn=uint16(H);
                end;

                for  i=yo:yn
                    for j=xo:xn
                        KeyFrame.R(i,j)=R(i,j);
                        KeyFrame.G(i,j)=G(i,j);
                        KeyFrame.B(i,j)=B(i,j);
                        KeyFrame.I(i,j)=I(i,j);
                    end;
                end;
            end;
        end
    end
    
    %%  WAVELET
    Id=im2double(I);
    Ikfd=im2double(KeyFrame.I);
    
    if  (time > Frame_first)
        for i=1:segn
            for j=1:segm
                %%
                % текущий кадр
                Imseg = Id((i-1)*Cell_size+1:i*Cell_size,(j-1)*Cell_size+1:j*Cell_size);
                [LL1,LH1,HL1,HH1]=dwt2(Imseg,'haar');
                Esum=0;
                Esum1=0;
                [wn,wm]=size(HH1);
                % эталонный кадр
                ImsegEt = Ikfd((i-1)*Cell_size+1:i*Cell_size,(j-1)*Cell_size+1:j*Cell_size);
                [LL2,LH2,HL2,HH2]=dwt2(ImsegEt,'haar');
                EsumEt=0;
                
                % суммирование в зоне
                for y=1:wn
                    for x=1:wm
                        % сумма по всем коэф.
                        E=abs((HL1(x,y)^2)+(LH1(x,y)^2)+(HH1(x,y)^2));
                        Esum=Esum+E;
                        Eet=abs((LH2(x,y)^2)+(HL2(x,y)^2)+(HH2(x,y)^2));
                        EsumEt=EsumEt+Eet;
                    end
                end
                
                Esum=(CoefMult2*Esum)+1;
                EsumEt=(CoefMult2*EsumEt)+1;
                Etable(i,j)=int32(Esum/100);
                EtableEt(i,j)=int32(EsumEt/100);
                Delta_E_low=((EsumEt-Esum)/EsumEt);
                
                if (Delta_E_low > Wav_Th) && (~reset_wlow_mask(i,j)) %Падение энергии в сегменте и 582:сброс по отсутсвию движения
                    W_flag_low(i,j)=true;
                else
                    W_flag_low(i,j)=false;
                end;
            end
        end
    end
end

%% Вывод данных
if time>=20
    %Рисование Movepic
    for i=1:segn
        for j=1:segm
            
            if Cells(i,j).MoveMask==0 %W_flag_low(i,j)
                Imseg1 =uint8(zeros(Cell_size,Cell_size));
            else
                Imseg1 = I((i-1)*Cell_size+1:i*Cell_size,(j-1)*Cell_size+1:j*Cell_size);
                %Imseg1 = step(txins,Imseg1, Etable(i,j));
            end
            
            Imtab((i-1)*Cell_size+1:i*Cell_size,(j-1)*Cell_size+1:j*Cell_size) = Imseg1;
        end
    end
end

% 845 Рисование цветовой маски и средней Е
Etablesum=int32(0); %845
EtablesumEt=int32(0);%845

for n=1:Vsize
    for m=1:Hsize
        BKG_out(n,m)=Cells(n,m).MoveMask;
        Etablesum=Etablesum+Etable(n,m); %845
        EtablesumEt=EtablesumEt+EtableEt(n,m); %845
    end;
end;

Emean=(Etablesum/int32(Vsize*Hsize)); %845
Emeanout=Emean;                 %845
EmeanEt=(EtablesumEt/int32(Vsize*Hsize)); %845
EmeanEtout=EmeanEt;             %845

Imean_Prev=Imean;
Imean_out=Imean;
Elow=W_flag_low;
Etableout=Etable;





