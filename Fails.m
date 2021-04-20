% ����� ������� ������� ������������� ����� �����, �������� �� ���� ����� �
% ������ ������������

function Fails = func(Emean,EmeanEt,Imean,BKG,Elow,go)

Emax=0.5;% ����� ��� ������������� ���������� ��� � �������� �������
Mmax=0.7;% ����� ��� ������������� ���������� ��� ��������

Emean_thr=0.7;% ����� ������� ������� ������� �����
Imin=40;% ������ ����� ������� ������� �����

[asizeE,bsizeE]=size(Elow);
% ������� ��� ������������ �������
persistent Fail_table
if isempty (Fail_table)
    Fail_table=false(3,1);%1-������ ��������� �����,2-����� ��������
end
persistent much_smoke
if isempty (much_smoke)
    much_smoke=false;%������� ����������
end
%������ ���-�� ���
Zcount=(asizeE-1)*(bsizeE-1);
Mcount=0;
Ecount=0;

if go==1
    %������ �� �����
    for i=1:asizeE
        for j=1:bsizeE
            if BKG(i,j)
                %���-�� ��� c ���������
                Mcount=Mcount+1;
            end
            if Elow(i,j)
                %���-�� ��� c ���������
                Ecount=Ecount+1;
            end
        end
    end
    
    Fail_table(2)=false;
    much_smoke = false;
    % ���� �� �����
    if Imean > Imin
        Fail_table(1)=false;
        otnM=Mcount/Zcount;
        otnE=Ecount/Zcount;
        otnEmean=double(Emean)/double(EmeanEt);
        
        %% �������� � ����� ������������ �������
        if otnM >= Mmax
            Fail_table(2)=true;
        else
            Fail_table(2)=false;
        end
        %% �������� � ����� ������������ �������
        if otnEmean < Emean_thr
            if otnE >= Emax
                much_smoke=true;
            end
        else
            much_smoke=false;
        end
        
        %% ���� ������� ���� ����� ����������, ���  ������
        if EmeanEt>Emean
            if otnE>Emean_thr
                otnEmean < Emean_thr
            else
                Fail_table(1)=true;
            end
        end
    end
end
Fails=false(3,1);
